import SwiftUI
import Supabase

struct FleetManagerNotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var unreadCount: Int = 0
    
    // MARK: - Routing State for Modal
    @State private var routingWorkOrder: WorkOrder? = nil
    @State private var routingDriverReport: DriverReport? = nil
    @State private var fetchError: String? = nil
    @State private var isRoutingActive = false
    
    var onUnreadCountChanged: ((Int) -> Void)? = nil
    
    // Real-time channel
    @State private var realtimeChannel: RealtimeChannelV2?
    
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
                            routingDriverReport = nil
                            fetchError = nil
                            isRoutingActive = true
                            
                            // 3. Fetch the actual data in the background
                            Task {
                                await fetchDataAndRoute(notification)
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
            await setupRealtimeNotifications()
        }
        .refreshable {
            await fetchNotifications()
        }
        .onDisappear {
            if let channel = realtimeChannel {
                Task { await SupabaseManager.shared.client.realtimeV2.removeChannel(channel) }
            }
        }
        // FIXED: Using an extracted View with Bindings completely bypasses the SwiftUI state freeze bug
        .sheet(isPresented: $isRoutingActive) {
            NotificationModalContainer(
                workOrder: $routingWorkOrder,
                driverReport: $routingDriverReport,
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
                .eq("recipient_id", value: currentUserId)
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
    
    private func setupRealtimeNotifications() async {
        guard realtimeChannel == nil else { return }
        
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let currentUserId = session.user.id
            
            let channel = SupabaseManager.shared.client.realtimeV2.channel("notifications-changes")
            self.realtimeChannel = channel
            
            let insertions = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "notifications"
            )
            
            try await channel.subscribeWithError()
            
            Task {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                for await action in insertions {
                    await MainActor.run {
                        switch action {
                        case .insert(let action):
                            // Manually filter for recipient_id to avoid deprecated filter syntax
                            guard action.record["recipient_id"]?.stringValue == currentUserId.uuidString else { return }
                            
                            if let newNotif = try? action.decodeRecord(as: AppNotification.self, decoder: decoder) {
                                // Add to top if not already present
                                if !notifications.contains(where: { $0.id == newNotif.id }) {
                                    notifications.insert(newNotif, at: 0)
                                    unreadCount = notifications.filter { !$0.isRead }.count
                                    onUnreadCountChanged?(unreadCount)
                                }
                            }
                        case .update(let action):
                            guard action.record["recipient_id"]?.stringValue == currentUserId.uuidString else { return }
                            
                            if let updatedNotif = try? action.decodeRecord(as: AppNotification.self, decoder: decoder) {
                                if let index = notifications.firstIndex(where: { $0.id == updatedNotif.id }) {
                                    notifications[index] = updatedNotif
                                    unreadCount = notifications.filter { !$0.isRead }.count
                                    onUnreadCountChanged?(unreadCount)
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }
        } catch {
            print("🚨 Failed to setup Realtime notifications: \(error)")
        }
    }
    
    private func markNotificationAsReadInDB(notificationId: UUID) async {
        do {
            struct UpdateRead: Encodable { let is_read: Bool }
            try await SupabaseManager.shared.client
                .from("notifications")
                .update(UpdateRead(is_read: true))
                .eq("id", value: notificationId)
                .execute()
        } catch {
            print("🚨 Failed to mark as read in DB: \(error)")
        }
    }
    
    // MARK: - Route to Data
    private func fetchDataAndRoute(_ notification: AppNotification) async {
        guard let entityId = notification.relatedEntityId else {
            await MainActor.run { self.fetchError = "No related entity ID attached to this notification." }
            return
        }
        
        do {
            if notification.type == .driverReport {
                // Fetch Driver Report
                let fetchedReports: [DriverReport] = try await SupabaseManager.shared.client
                    .from("driver_reports")
                    .select("*, vehicles(vehicle_id, vin, number_plate, vehicle_name, vehicle_type)")
                    .eq("id", value: entityId.uuidString)
                    .execute()
                    .value
                
                await MainActor.run {
                    if let targetReport = fetchedReports.first {
                        self.routingDriverReport = targetReport
                    } else {
                        self.fetchError = "Driver report no longer exists or couldn't be found."
                    }
                }
            } else {
                // Default: Fetch Work Order
                let fetchedOrders: [WorkOrder] = try await SupabaseManager.shared.client
                    .from("work_orders")
                    .select("*, vehicles(vehicle_id, vin, number_plate, vehicle_name, vehicle_type)")
                    .eq("work_order_id", value: entityId.uuidString)
                    .execute()
                    .value
                
                await MainActor.run {
                    if let targetOrder = fetchedOrders.first {
                        self.routingWorkOrder = targetOrder
                    } else {
                        self.fetchError = "Work order no longer exists or couldn't be found."
                    }
                }
            }
        } catch {
            print("🚨 Failed to fetch entity: \(error)")
            await MainActor.run {
                self.fetchError = "Network error: Failed to pull data from database."
            }
        }
    }
}

// MARK: - Extracted Modal Container
struct NotificationModalContainer: View {
    @Binding var workOrder: WorkOrder?
    @Binding var driverReport: DriverReport?
    @Binding var fetchError: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            if let workOrderToView = workOrder {
                WorkOrderDetailView(
                    workOrder: workOrderToView,
                    isManagerApprovalMode: true
                )
            } else if let reportToView = driverReport {
                if let v = reportToView.vehicle {
                    MaintenanceStaffPickerView(
                        vehicle: Vehicle(workOrderVehicle: v),
                        driverReportId: reportToView.id,
                        initialSummary: "\(reportToView.category.rawValue.capitalized) Issue",
                        initialDescription: reportToView.description
                    )
                } else {
                    DriverReportDetailView(report: reportToView)
                }
            } else if let errorMsg = fetchError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Could not load Details")
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
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Fetching Details...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
