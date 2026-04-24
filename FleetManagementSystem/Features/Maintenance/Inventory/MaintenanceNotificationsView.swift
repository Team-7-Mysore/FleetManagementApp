import SwiftUI
import Supabase

struct MaintenanceNotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @Binding var unreadCount: Int

    // MARK: - Routing States
    // 1. For unapproved/new tasks (Push Navigation)
    @State private var routingDataForEdit: NotificationRoutingData? = nil
    // 2. For approved work orders (Modal Sheet)
    @State private var workOrderForDetails: WorkOrder? = nil

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if isLoading {
                ProgressView("Loading Notifications...")
            } else if notifications.isEmpty {
                VStack(spacing:20) {
                    Image(systemName:"bell.slash")
                        .font(.system(size:60))
                        .foregroundColor(.secondary)

                    Text("No notifications")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            } else {
                List {
                    ForEach($notifications) { $notification in
                        Button {
                            // 1. Mark as read
                            if !notification.isRead {
                                notification.isRead = true
                                unreadCount = max(0, unreadCount - 1)
                                Task {
                                    await markNotificationAsReadInDB(notificationId: notification.id)
                                }
                            }

                            // 2. Fetch data and route dynamically based on approval status
                            Task {
                                await fetchAndRoute(notification)
                            }

                        } label: {
                            HStack(alignment:.top, spacing:12) {
                                Circle()
                                    .fill(notification.isRead ? Color.clear : .blue)
                                    .frame(width:10,height:10)
                                    .padding(.top,5)

                                VStack(alignment:.leading, spacing:6) {
                                    HStack {
                                        Image(systemName: notification.type.systemImage)
                                            .foregroundColor(notification.isRead ? .gray : .blue)

                                        Text(notification.title)
                                            .font(.headline)
                                            .fontWeight(notification.isRead ? .regular : .bold)
                                    }

                                    Text(notification.message)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)

                                    Text(notification.createdAt, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical,4)
                        }
                        .buttonStyle(.plain)
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
        // MARK: - Route 1: Navigation to Add/Edit Work Order (Unapproved/New Tasks)
        .navigationDestination(item: $routingDataForEdit) { data in
            AddEditWorkOrderView(
                sourceIssueId: data.issueId,
                preSelectedVehicleId: data.vehicleId,
                prefilledSummary: data.summary,
                prefilledDescription: data.description,
                managerId: data.senderId
            )
        }
        // MARK: - Route 2: Modal to Work Order Details (Approved Orders to Start Work)
        .sheet(item: $workOrderForDetails) { workOrderToView in
            NavigationStack {
                WorkOrderDetailView(
                    workOrder: workOrderToView,
                    isManagerApprovalMode: false // Mechanic sees "Start Work Order"
                )
            }
            .presentationDetents([.large])
        }
    }

    // MARK: - Database Fetching
    private func fetchNotifications() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let currentUserId = session.user.id

            let fetched:[AppNotification] = try await SupabaseManager.shared.client
                .from("notifications")
                .select()
                .eq("recipient_id", value: currentUserId.uuidString)
                .order("created_at", ascending:false)
                .execute()
                .value

            await MainActor.run {
                notifications = fetched
                unreadCount = fetched.filter { !$0.isRead }.count
                isLoading = false
            }
        } catch {
            print(error)
            await MainActor.run { isLoading = false }
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
            print(error)
        }
    }

    // MARK: - Smart Routing Logic
    private func fetchAndRoute(_ notification: AppNotification) async {
        guard let entityId = notification.relatedEntityId else { return }

        do {
            // First, try to fetch it as a Work Order
            let fetchedOrders: [WorkOrder] = try await SupabaseManager.shared.client
                .from("work_orders")
                .select("*, vehicles(vehicle_id, vin, number_plate, vehicle_name, vehicle_type)")
                .eq("work_order_id", value: entityId.uuidString)
                .execute()
                .value

            if let targetOrder = fetchedOrders.first {
                await MainActor.run {
                    if targetOrder.isApproved {
                        // APPROVED: Open Details View Modal so they can click "Start Work Order"
                        self.workOrderForDetails = targetOrder
                    } else {
                        // PENDING (Not Approved): Navigate to Add/Edit View to draft it for approval
                        self.routingDataForEdit = NotificationRoutingData(
                            issueId: targetOrder.workOrderId,
                            vehicleId: targetOrder.vehicleId,
                            summary: targetOrder.issueTitle,
                            description: targetOrder.issueDescription ?? "",
                            senderId: notification.senderId
                        )
                    }
                }
                return
            }

            // Fallback: If it's not a Work Order, it might be a raw Maintenance Issue
            struct IssueDetails: Decodable {
                let vehicle_id: UUID
                let issue_summary: String?
                let description: String?
            }

            let fetchedIssues: [IssueDetails] = try await SupabaseManager.shared.client
                .from("maintenance_issues")
                .select("vehicle_id, issue_summary, description")
                .eq("issue_id", value: entityId.uuidString)
                .execute()
                .value

            if let issueData = fetchedIssues.first {
                await MainActor.run {
                    self.routingDataForEdit = NotificationRoutingData(
                        issueId: entityId,
                        vehicleId: issueData.vehicle_id,
                        summary: issueData.issue_summary ?? "",
                        description: issueData.description ?? "",
                        senderId: notification.senderId
                    )
                }
            }

        } catch {
            print("🚨 Failed to fetch for routing: \(error)")
        }
    }
}

// MARK: - Supporting Data Type
struct NotificationRoutingData: Identifiable, Hashable {
    let id = UUID()
    let issueId: UUID
    let vehicleId: UUID?
    let summary: String
    let description: String
    let senderId: UUID?
}
