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
    @State private var showingClearConfirmation = false
    @State private var selectedNotifications = Set<UUID>()
    @State private var editMode: EditMode = .inactive

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
                List(selection: $selectedNotifications) {
                    ForEach(notifications) { notification in
                        notificationRow(for: notification)
                            .tag(notification.id)
                    }
                    .onDelete(perform: deleteFromSwipe)
                }
                .listStyle(.insetGrouped)
                .environment(\.editMode, $editMode)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if editMode == .active {
                    Button(selectedNotifications.count == notifications.count ? "Deselect All" : "Select All") {
                        if selectedNotifications.count == notifications.count {
                            selectedNotifications.removeAll()
                        } else {
                            selectedNotifications = Set(notifications.map { $0.id })
                        }
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(editMode == .active ? "Done" : "Select") {
                    withAnimation {
                        editMode = (editMode == .active) ? .inactive : .active
                    }
                }
                .fontWeight(editMode == .active ? .bold : .medium)
            }

            if editMode == .active {
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Button(role: .destructive) {
                            Task {
                                await deleteSelectedNotifications()
                            }
                        } label: {
                            Text("Delete\(selectedNotifications.isEmpty ? "" : " (\(selectedNotifications.count))")")
                                .foregroundColor(selectedNotifications.isEmpty ? .secondary : .red)
                        }
                        .disabled(selectedNotifications.isEmpty)
                        
                        Spacer()
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear all notifications?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                Task {
                    await clearAllNotifications()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
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
        .onChange(of: editMode) { newValue in
            if newValue == .inactive {
                selectedNotifications.removeAll()
            }
        }
        .sheet(isPresented: $isRoutingActive) {
            NotificationModalContainer(
                workOrder: $routingWorkOrder,
                driverReport: $routingDriverReport,
                fetchError: $fetchError
            )
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func notificationRow(for notification: AppNotification) -> some View {
        Button(action: {
            if editMode == .active {
                if selectedNotifications.contains(notification.id) {
                    selectedNotifications.remove(notification.id)
                } else {
                    selectedNotifications.insert(notification.id)
                }
                return
            }

            // 1. Handle Unread Status
            if !notification.isRead {
                if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                    notifications[index].isRead = true
                }
                unreadCount = max(0, unreadCount - 1)
                onUnreadCountChanged?(unreadCount)

                let notifId = notification.id
                Task {
                    await markNotificationAsReadInDB(notificationId: notifId)
                }
            }

            let currentNotif = notification

            // Check if we should open the modal
            let destination = notificationDestination(for: currentNotif)
            if case .none = destination {
                return
            }

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
            .opacity(notification.isRead ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func deleteFromSwipe(at offsets: IndexSet) {
        let notificationsToDelete = offsets.map { notifications[$0] }
        Task {
            for notif in notificationsToDelete {
                await deleteNotificationByID(notif.id)
            }
        }
        notifications.remove(atOffsets: offsets)
        unreadCount = notifications.filter { !$0.isRead }.count
        onUnreadCountChanged?(unreadCount)
    }

    private func deleteNotificationByID(_ id: UUID) async {
        do {
            print("🗑️ Attempting to delete notification from DB with ID: \(id)")
            try await SupabaseManager.shared.client
                .from("notifications")
                .delete()
                .eq("id", value: id)
                .execute()
            
            print("✅ Successfully deleted notification \(id) from Supabase")
        } catch {
            print("🚨 Exception during delete notification \(id): \(error)")
        }
    }

    // MARK: - Database Actions
    private func fetchNotifications() async {
        do {
            let currentUserId: UUID
            if let id = userId {
                currentUserId = id
            } else {
                let session = try await SupabaseManager.shared.client.auth.session
                currentUserId = session.user.id
            }

            print("📡 Fetching notifications for user: \(currentUserId)")
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
            if let id = userId { currentUserId = id }
            else { currentUserId = try await SupabaseManager.shared.client.auth.session.user.id }

            let channel = SupabaseManager.shared.client.realtimeV2.channel("notifications-changes")
            self.realtimeChannel = channel

            let insertions = channel.postgresChange(AnyAction.self, schema: "public", table: "notifications")
            try await channel.subscribeWithError()

            Task {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                for await action in insertions {
                    await MainActor.run {
                        switch action {
                        case .insert(let action):
                            guard action.record["recipient_id"]?.stringValue == currentUserId.uuidString else { return }
                            if let newNotif = try? action.decodeRecord(as: AppNotification.self, decoder: decoder) {
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
                        default: break
                        }
                    }
                }
            }
        } catch { print("🚨 Realtime setup failed: \(error)") }
    }

    private func markNotificationAsReadInDB(notificationId: UUID) async {
        do {
            try await SupabaseManager.shared.client
                .from("notifications")
                .update(["is_read": true])
                .eq("id", value: notificationId)
                .execute()
        } catch { print("🚨 Mark as read failed: \(error)") }
    }

    private func clearAllNotifications() async {
        do {
            let currentUserId: UUID
            if let id = userId {
                currentUserId = id
            } else {
                let session = try await SupabaseManager.shared.client.auth.session
                currentUserId = session.user.id
            }

            print("🗑️ Attempting to clear all notifications for user: \(currentUserId)")
            try await SupabaseManager.shared.client
                .from("notifications")
                .delete()
                .eq("recipient_id", value: currentUserId)
                .execute()

            print("✅ Successfully cleared all notifications from Supabase")
            await MainActor.run {
                self.notifications = []
                self.unreadCount = 0
                onUnreadCountChanged?(0)
                self.selectedNotifications.removeAll()
            }
        } catch {
            print("🚨 Exception in clearAllNotifications: \(error)")
        }
    }

    private func deleteSelectedNotifications() async {
        guard !selectedNotifications.isEmpty else { return }
        
        do {
            let idsToDelete = Array(selectedNotifications)
            print("🗑️ Attempting to delete selected notifications: \(idsToDelete)")
            
            try await SupabaseManager.shared.client
                .from("notifications")
                .delete()
                .in("id", values: idsToDelete)
                .execute()

            print("✅ Successfully deleted selected notifications from Supabase")
            await MainActor.run {
                self.notifications.removeAll { selectedNotifications.contains($0.id) }
                self.unreadCount = self.notifications.filter { !$0.isRead }.count
                onUnreadCountChanged?(self.unreadCount)
                self.selectedNotifications.removeAll()
                self.editMode = .inactive
            }
        } catch {
            print("🚨 Exception in deleteSelectedNotifications: \(error)")
        }
    }

    // MARK: - Routing Logic
    private func fetchDataAndRoute(_ notification: AppNotification) async {
        guard let entityId = notification.relatedEntityId else {
            await MainActor.run { self.fetchError = "No related entity ID." }
            return
        }

        do {
            switch notificationDestination(for: notification) {
            case .driverReport:
                if let report = try await fetchDriverReport(for: notification, entityId: entityId) {
                    await MainActor.run { self.routingDriverReport = report }
                } else {
                    await MainActor.run { self.fetchError = "Driver report not found." }
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
                        self.fetchError = "Work order not found."
                    }
                }
            case .unsupported(let message):
                await MainActor.run { self.fetchError = message }
            case .none:
                break
            }
        } catch {
            await MainActor.run { self.fetchError = error.localizedDescription }
        }
    }

    private func notificationDestination(for notification: AppNotification) -> NotificationDestination {
        let normalizedTitle = notification.title.lowercased()
        let normalizedMessage = notification.message.lowercased()
        if notification.type == .maintenance { return .workOrder }
        if notification.type == .driverReport { return .driverReport }
        if normalizedTitle.contains("issue reported") || normalizedTitle.contains("driver report") { return .driverReport }
        if normalizedTitle.contains("route deviation") || normalizedMessage.contains("route deviation") { return .none }
        return .unsupported("Notification type not supported yet.")
    }

    private func fetchDriverReport(for notification: AppNotification, entityId: UUID) async throws -> DriverReport? {
        if let byId = try await fetchDriverReportByReportId(entityId) {
            return byId
        }
        let vehicleMatches = try await fetchDriverReportsByVehicleId(entityId)
        guard !vehicleMatches.isEmpty else {
            return try await buildNotificationBackedDriverReport(notification: notification, vehicleId: entityId)
        }
        if let matchedByCategory = matchDriverReport(vehicleMatches, to: notification) { return matchedByCategory }
        return vehicleMatches.first
    }

    private func fetchDriverReportByReportId(_ reportId: UUID) async throws -> DriverReport? {
        do {
            let targetReport: DriverReport = try await SupabaseManager.shared.client
                .from("driver_reports")
                .select("*, vehicle:vehicles(vehicle_id, vin, number_plate, vehicle_name, vehicle_type)")
                .eq("id", value: reportId.uuidString)
                .single()
                .execute()
                .value
            return targetReport
        } catch let error as PostgrestError {
            print("⚠️ PGRST116: Not a direct report ID, checking vehicle ID...")
            return nil
        } catch { throw error }
    }

    private func fetchDriverReportsByVehicleId(_ vehicleId: UUID) async throws -> [DriverReport] {
        return try await SupabaseManager.shared.client
            .from("driver_reports")
            .select("*, vehicle:vehicles(vehicle_id, vin, number_plate, vehicle_name, vehicle_type)")
            .eq("vehicle_id", value: vehicleId.uuidString)
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value
    }

    // MARK: - Matching & Parsing Helpers
    private func matchDriverReport(_ reports: [DriverReport], to notification: AppNotification) -> DriverReport? {
        let categoryHint = extractCategoryHint(from: notification.message)
        if let categoryHint {
            if let match = reports.first(where: { $0.category.rawValue.caseInsensitiveCompare(categoryHint) == .orderedSame }) {
                return match
            }
        }
        return reports.min { lhs, rhs in
            abs((lhs.createdAt ?? .distantPast).timeIntervalSince(notification.createdAt)) < abs((rhs.createdAt ?? .distantPast).timeIntervalSince(notification.createdAt))
        }
    }

    private func buildNotificationBackedDriverReport(notification: AppNotification, vehicleId: UUID) async throws -> DriverReport? {
        var vehicle: WorkOrderVehicle? = nil
        do {
            vehicle = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("vehicle_id, vin, number_plate, vehicle_name, vehicle_type")
                .eq("vehicle_id", value: vehicleId.uuidString)
                .single()
                .execute()
                .value
        } catch { print("⚠️ Vehicle fetch failed for backfill") }

        return DriverReport(
            id: notification.id,
            driverId: nil,
            vehicleId: vehicleId,
            tripId: nil,
            category: extractCategory(from: notification.message) ?? .other,
            severity: extractSeverity(from: notification.message) ?? .medium,
            description: notification.message,
            status: .reported,
            createdAt: notification.createdAt,
            vehicle: vehicle
        )
    }

    private func extractCategoryHint(from message: String) -> String? {
        guard let separatorIndex = message.lastIndex(of: ":") else { return nil }
        let rawSuffix = message[message.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if rawSuffix.contains("mechanical") { return "mechanical" }
        if rawSuffix.contains("electrical") { return "electrical" }
        if rawSuffix.contains("tyre") { return "tyre/wheel" }
        if rawSuffix.contains("fluid") { return "fluid leak" }
        if rawSuffix.contains("body") { return "body damage" }
        if rawSuffix.contains("safety") { return "safety" }
        return nil
    }

    private func extractCategory(from message: String) -> DriverReportCategory? {
        let hint = extractCategoryHint(from: message)
        if hint == "mechanical" { return .mechanical }
        if hint == "electrical" { return .electrical }
        if hint == "tyre/wheel" { return .tyreWheel }
        if hint == "fluid leak" { return .fluidLeak }
        if hint == "body damage" { return .bodyDamage }
        if hint == "safety" { return .safety }
        return .other
    }

    private func extractSeverity(from message: String) -> DriverReportSeverity? {
        let normalized = message.lowercased()
        if normalized.contains("critical") { return .critical }
        if normalized.contains("low") { return .low }
        return .medium
    }
}

private enum NotificationDestination {
    case workOrder
    case driverReport
    case unsupported(String)
    case none
}

// MARK: - Modal Container
struct NotificationModalContainer: View {
    @Binding var workOrder: WorkOrder?
    @Binding var driverReport: DriverReport?
    @Binding var fetchError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let workOrderToView = workOrder {
                WorkOrderDetailView(workOrder: workOrderToView, isManagerApprovalMode: true)
            } else if let reportToView = driverReport {
                if let reportVehicle = reportToView.vehicle {
                    MaintenanceStaffPickerView(
                        vehicle: Vehicle(workOrderVehicle: reportVehicle),
                        driverReportId: reportToView.id,
                        initialSummary: "\(reportToView.category.rawValue.capitalized) Issue: \(reportToView.severity.rawValue.capitalized)",
                        initialDescription: reportToView.description
                    )
                } else {
                    VStack {
                        Image(systemName: "car.fill").font(.largeTitle).foregroundColor(.gray)
                        Text("Vehicle details missing.")
                    }.toolbar { Button("Close") { dismiss() } }
                }
            } else if let errorMsg = fetchError {
                VStack {
                    Text("Error").font(.headline)
                    Text(errorMsg).foregroundColor(.secondary)
                }.toolbar { Button("Close") { dismiss() } }
            } else {
                ProgressView("Loading Details...")
            }
        }
    }
}
