import SwiftUI
import Supabase

struct FleetManagerNotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var unreadCount: Int = 0
    
    // MARK: - Routing State for Modal
    @State private var routingWorkOrder: WorkOrder? = nil
    @State private var fetchError: String? = nil
    @State private var isRoutingToWorkOrder = false
    
    var onUnreadCountChanged: ((Int) -> Void)? = nil
    
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
                            // 1. Handle Unread Status
                            if !notification.isRead {
                                notification.isRead = true
                                unreadCount = max(0, unreadCount - 1)
                                onUnreadCountChanged?(unreadCount)
                                
                                Task {
                                    await markNotificationAsReadInDB(notificationId: notification.id)
                                }
                            }
                            
                            // 2. Clear old data and show modal IMMEDIATELY
                            routingWorkOrder = nil
                            fetchError = nil
                            isRoutingToWorkOrder = true
                            
                            // 3. Fetch the actual data in the background
                            Task {
                                await fetchWorkOrderAndRoute(notification)
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
        // FIXED: Using an extracted View with Bindings completely bypasses the SwiftUI state freeze bug
        .sheet(isPresented: $isRoutingToWorkOrder) {
            WorkOrderModalContainer(
                workOrder: $routingWorkOrder,
                fetchError: $fetchError
            )
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Fetch Notifications
    private func fetchNotifications() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let currentUserId = session.user.id
            
            let fetched: [AppNotification] = try await SupabaseManager.shared.client
                .from("notifications")
                .select()
                .eq("recipient_id", value: currentUserId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                self.notifications = fetched
                self.unreadCount = fetched.filter { !$0.isRead }.count
                onUnreadCountChanged?(self.unreadCount)
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
    
    // MARK: - Route to Work Order
    private func fetchWorkOrderAndRoute(_ notification: AppNotification) async {
        guard let orderId = notification.relatedEntityId else {
            await MainActor.run { self.fetchError = "No Work Order ID attached to this notification." }
            return
        }
        
        do {
            let fetchedOrders: [WorkOrder] = try await SupabaseManager.shared.client
                .from("work_orders")
                .select("*, vehicles(vehicle_id, vin, number_plate, vehicle_name, vehicle_type)")
                .eq("work_order_id", value: orderId.uuidString)
                .execute()
                .value
            
            await MainActor.run {
                if let targetOrder = fetchedOrders.first {
                    self.routingWorkOrder = targetOrder // This updates the binding and reveals the UI
                } else {
                    self.fetchError = "Work order no longer exists or couldn't be found."
                }
            }
        } catch {
            print("🚨 Failed to fetch work order: \(error)")
            await MainActor.run {
                self.fetchError = "Network error: Failed to pull data from database."
            }
        }
    }
}

// MARK: - Extracted Modal Container
// This forces SwiftUI to listen to the @Binding and redraw when the data arrives!
struct WorkOrderModalContainer: View {
    @Binding var workOrder: WorkOrder?
    @Binding var fetchError: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            if let workOrderToView = workOrder {
                // SUCCESS: Data loaded, show details and Manager Approval buttons
                WorkOrderDetailView(
                    workOrder: workOrderToView,
                    isManagerApprovalMode: true
                )
            } else if let errorMsg = fetchError {
                // ERROR: Fetch failed, show why
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Could not load Work Order")
                        .font(.headline)
                    
                    Text(errorMsg)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
            } else {
                // LOADING: Data is still fetching
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Fetching Work Order...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
