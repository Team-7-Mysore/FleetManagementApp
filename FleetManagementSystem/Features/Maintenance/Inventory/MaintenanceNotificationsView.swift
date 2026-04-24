import SwiftUI
import Supabase

struct MaintenanceNotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var unreadCount: Int = 0
    
    // MARK: - Routing State for Push Navigation
    @State private var routingData: NotificationRoutingData? = nil
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            if isLoading {
                ProgressView("Loading Notifications...")
            } else if notifications.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No notifications")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            } else {
                List {
                    ForEach($notifications) { $notification in
                        Button(action: {
                            if !notification.isRead {
                                notification.isRead = true
                                unreadCount = max(0, unreadCount - 1)
                                
                                Task {
                                    await markNotificationAsReadInDB(notificationId: notification.id)
                                }
                            }
                            
                            Task {
                                await fetchIssueAndRoute(notification)
                            }
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(notification.isRead ? Color.clear : Color.blue)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 5)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: notification.type.systemImage)
                                            .foregroundColor(notification.isRead ? .gray : .blue)
                                        
                                        Text(notification.title)
                                            .font(.headline)
                                            .fontWeight(notification.isRead ? .regular : .bold)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Text(notification.message)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    
                                    Text(notification.createdAt, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await fetchNotifications()
        }
        .refreshable {
            await fetchNotifications()
        }
        .navigationDestination(item: $routingData) { data in
            AddEditWorkOrderView(
                sourceIssueId: data.issueId,
                preSelectedVehicleId: data.vehicleId,
                prefilledSummary: data.summary,
                prefilledDescription: data.description,
                managerId: data.senderId
            )
        }
    }
    
    // MARK: - Fetch Notifications (FILTERED BY LOGGED IN USER)
    private func fetchNotifications() async {
        do {
            // ✨ INTERNAL MAGIC: Get the logged-in user's ID
            let session = try await SupabaseManager.shared.client.auth.session
            let currentUserId = session.user.id
            
            let fetched: [AppNotification] = try await SupabaseManager.shared.client
                .from("notifications")
                .select()
                .eq("recipient_id", value: currentUserId.uuidString) // ✨ ONLY fetch their notifications!
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.notifications = fetched
                self.unreadCount = fetched.filter { !$0.isRead }.count
                self.isLoading = false
            }
        } catch {
            print("🚨 Failed to fetch notifications: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
    
    private func markNotificationAsReadInDB(notificationId: UUID) async {
        do {
            struct UpdateRead: Encodable { let is_read: Bool }
            try await SupabaseManager.shared.client
                .from("notifications")
                .update(UpdateRead(is_read: true))
                .eq("id", value: notificationId.uuidString)
                .execute()
        } catch {
            print("🚨 Failed to mark as read in DB: \(error)")
        }
    }
    
    private func fetchIssueAndRoute(_ notification: AppNotification) async {
        guard notification.type == .maintenance, let issueId = notification.relatedEntityId else { return }
        
        do {
            struct IssueDetails: Decodable {
                let vehicle_id: UUID
                let issue_summary: String?
                let description: String?
            }
            
            let issueData: IssueDetails = try await SupabaseManager.shared.client
                .from("maintenance_issues")
                .select("vehicle_id, issue_summary, description")
                .eq("issue_id", value: issueId.uuidString)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.routingData = NotificationRoutingData(
                    issueId: issueId,
                    vehicleId: issueData.vehicle_id,
                    summary: issueData.issue_summary ?? notification.title.replacingOccurrences(of: "New Task: ", with: ""),
                    description: issueData.description ?? "",
                    senderId: notification.senderId
                )
            }
            
        } catch {
            print("🚨 Failed to fetch issue details for routing: \(error)")
        }
    }
}

// Keep this struct here or move it to your Models file
struct NotificationRoutingData: Identifiable, Hashable {
    let id = UUID()
    let issueId: UUID
    let vehicleId: UUID?
    let summary: String
    let description: String
    let senderId: UUID?
}
