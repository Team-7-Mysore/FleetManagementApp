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
    
    // User Context
    let userId: UUID?
    
    // Real-time channel
    @State private var realtimeChannel: RealtimeChannelV2?
    
    init(userId: UUID? = nil, onUnreadCountChanged: ((Int) -> Void)? = nil) {
        self.userId = userId
        self.onUnreadCountChanged = onUnreadCountChanged
    }
    
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
                    ForEach(notifications.indices, id: \.self) { index in
                        Button(action: {
                            // 1. Handle Unread Status
                            if !notifications[index].isRead {
                                notifications[index].isRead = true
                                unreadCount = max(0, unreadCount - 1)
                                onUnreadCountChanged?(unreadCount)
                                
                                let notifId = notifications[index].id
                                Task {
                                    await markNotificationAsReadInDB(notificationId: notifId)
                                }
                            }
                            
                            let currentNotif = notifications[index]
                            
                            // 2. Clear old data and show modal IMMEDIATELY
                            routingWorkOrder = nil
                            routingDriverReport = nil
                            fetchError = nil
                            isRoutingActive = true
                            
                            // 3. Fetch the actual data in the background
                            Task {
                                await fetchDataAndRoute(currentNotif)
                            }
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(notifications[index].isRead ? Color.clear : Color.blue)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 5)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: notifications[index].type.systemImage)
                                            .foregroundColor(notifications[index].isRead ? .gray : .blue)
                                        
                                        Text(notifications[index].title)
                                            .font(.headline)
                                            .fontWeight(notifications[index].isRead ? .regular : .bold)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Text(notifications[index].message)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    
                                    Text(notifications[index].createdAt, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 4)
                            .opacity(notifications[index].isRead ? 0.6 : 1.0)
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
            let currentUserId: UUID
            if let id = userId {
                currentUserId = id
            } else {
                let session = try await SupabaseManager.shared.client.auth.session
                currentUserId = session.user.id
            }
            
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
            let currentUserId: UUID
            if let id = userId {
                currentUserId = id
            } else {
                let session = try await SupabaseManager.shared.client.auth.session
                currentUserId = session.user.id
            }
            
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
            // Using a dictionary for partial update is often more reliable with Supabase Swift SDK
            let updateData: [String: Bool] = ["is_read": true]
            
            try await SupabaseManager.shared.client
                .from("notifications")
                .update(updateData)
                .eq("id", value: notificationId)
                .execute()
                
            print("✅ Successfully marked notification \(notificationId) as read in DB")
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
            switch notificationDestination(for: notification) {
            case .driverReport:
                if let report = try await fetchDriverReport(for: notification, entityId: entityId) {
                    await MainActor.run {
                        self.routingDriverReport = report
                    }
                } else {
                    await MainActor.run {
                        self.fetchError = "Driver report could not be found for this notification."
                    }
                }
            case .workOrder:
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
            case .unsupported(let message):
                await MainActor.run {
                    self.fetchError = message
                }
            }
        } catch {
            print("🚨 Failed to fetch entity: \(error)")
            await MainActor.run {
                self.fetchError = "Network error: Failed to pull data from database."
            }
        }
    }

    private func notificationDestination(for notification: AppNotification) -> NotificationDestination {
        let normalizedTitle = notification.title.lowercased()
        let normalizedMessage = notification.message.lowercased()

        if notification.type == .maintenance {
            return .workOrder
        }

        if notification.type == .driverReport {
            return .driverReport
        }

        if normalizedTitle.contains("issue reported")
            || normalizedTitle.contains("driver report")
            || normalizedMessage.contains("issue reported") {
            return .driverReport
        }

        if normalizedTitle.contains("route deviation")
            || normalizedMessage.contains("deviated") {
            return .unsupported("This alert does not open a work order or driver report.")
        }

        return .unsupported("This notification type does not have a detail screen yet.")
    }

    private func fetchDriverReport(
        for notification: AppNotification,
        entityId: UUID
    ) async throws -> DriverReport? {
        if let byId = try await fetchDriverReportByReportId(entityId) {
            return byId
        }

        let vehicleMatches = try await fetchDriverReportsByVehicleId(entityId)
        guard !vehicleMatches.isEmpty else { return nil }

        if let matchedByCategory = matchDriverReport(vehicleMatches, to: notification) {
            return matchedByCategory
        }

        if let firstVehicleMatch = vehicleMatches.first {
            return firstVehicleMatch
        }

        return try await buildNotificationBackedDriverReport(notification: notification, vehicleId: entityId)
    }

    private func fetchDriverReportByReportId(_ reportId: UUID) async throws -> DriverReport? {
        do {
            let targetReport: DriverReport = try await SupabaseManager.shared.client
                .from("driver_reports")
                .select("*, vehicles(vehicle_id, vin, number_plate, vehicle_name, vehicle_type)")
                .eq("id", value: reportId.uuidString)
                .single()
                .execute()
                .value
            return targetReport
        } catch {
            print("⚠️ Driver report lookup by report id \(reportId.uuidString) failed: \(error)")
        }

        do {
            let fallbackReport: DriverReport = try await SupabaseManager.shared.client
                .from("driver_reports")
                .select()
                .eq("id", value: reportId.uuidString)
                .single()
                .execute()
                .value
            return fallbackReport
        } catch {
            print("⚠️ Plain driver report lookup by report id \(reportId.uuidString) failed: \(error)")
            return nil
        }
    }

    private func fetchDriverReportsByVehicleId(_ vehicleId: UUID) async throws -> [DriverReport] {
        do {
            let reports: [DriverReport] = try await SupabaseManager.shared.client
                .from("driver_reports")
                .select("*, vehicles(vehicle_id, vin, number_plate, vehicle_name, vehicle_type)")
                .eq("vehicle_id", value: vehicleId.uuidString)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            if !reports.isEmpty { return reports }
        } catch {
            print("⚠️ Joined driver report lookup by vehicle id \(vehicleId.uuidString) failed: \(error)")
        }

        let fallbackReports: [DriverReport] = try await SupabaseManager.shared.client
            .from("driver_reports")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value
        return fallbackReports
    }

    private func matchDriverReport(
        _ reports: [DriverReport],
        to notification: AppNotification
    ) -> DriverReport? {
        let categoryHint = extractCategoryHint(from: notification.message)

        if let categoryHint {
            let categoryMatch = reports.first { report in
                report.category.rawValue.caseInsensitiveCompare(categoryHint) == .orderedSame
            }
            if let categoryMatch {
                return categoryMatch
            }
        }

        return reports.min { lhs, rhs in
            let lhsDelta = abs((lhs.createdAt ?? .distantPast).timeIntervalSince(notification.createdAt))
            let rhsDelta = abs((rhs.createdAt ?? .distantPast).timeIntervalSince(notification.createdAt))
            return lhsDelta < rhsDelta
        }
    }

    private func buildNotificationBackedDriverReport(
        notification: AppNotification,
        vehicleId: UUID
    ) async throws -> DriverReport? {
        let vehicle: WorkOrderVehicle?

        do {
            vehicle = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("vehicle_id, vin, number_plate, vehicle_name, vehicle_type")
                .eq("vehicle_id", value: vehicleId.uuidString)
                .single()
                .execute()
                .value
        } catch {
            print("⚠️ Failed to fetch vehicle \(vehicleId.uuidString) for notification-backed driver report: \(error)")
            vehicle = nil
        }

        let category = extractCategory(from: notification.message) ?? .other
        let severity = extractSeverity(from: notification.message) ?? .medium

        return DriverReport(
            id: notification.id,
            driverId: nil,
            vehicleId: vehicleId,
            tripId: nil,
            category: category,
            severity: severity,
            description: notification.message,
            status: .reported,
            createdAt: notification.createdAt,
            vehicle: vehicle
        )
    }

    private func extractCategoryHint(from message: String) -> String? {
        guard let separatorIndex = message.lastIndex(of: ":") else { return nil }
        let rawSuffix = message[message.index(after: separatorIndex)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .lowercased()

        switch rawSuffix {
        case "mechanical":
            return "mechanical"
        case "electrical":
            return "electrical"
        case "tyre/wheel", "tyre wheel":
            return "tyre/wheel"
        case "fluid leak":
            return "fluid leak"
        case "bodywork", "body damage":
            return "body damage"
        case "safety":
            return "safety"
        case "other":
            return "other"
        default:
            return nil
        }
    }

    private func extractCategory(from message: String) -> DriverReportCategory? {
        switch extractCategoryHint(from: message) {
        case "mechanical":
            return .mechanical
        case "electrical":
            return .electrical
        case "tyre/wheel":
            return .tyreWheel
        case "fluid leak":
            return .fluidLeak
        case "body damage":
            return .bodyDamage
        case "safety":
            return .safety
        case "other":
            return .other
        default:
            return nil
        }
    }

    private func extractSeverity(from message: String) -> DriverReportSeverity? {
        let normalized = message.lowercased()
        if normalized.contains("critical") { return .critical }
        if normalized.contains("low") { return .low }
        if normalized.contains("medium") { return .medium }
        return nil
    }
}

private enum NotificationDestination {
    case workOrder
    case driverReport
    case unsupported(String)
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
                DriverReportDetailView(report: reportToView)
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
