import SwiftUI
import Supabase

struct WorkOrdersView: View {
    let profile: UserProfile?
    let onSignOut: () async -> Void

    @StateObject private var viewModel = WorkOrderViewModel()
    @State private var unreadNotificationCount = 0

    @State private var selectedDetailOrder: WorkOrder?
    @State private var selectedReportOrder: WorkOrder?
    @State private var showingProfile = false
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: Top Cards
                    HStack(spacing: 12) {

                        NavigationLink(
                            destination: FilteredWorkOrdersView(
                                title: "Pending Orders",
                                sections: [
                                    ("Approved", viewModel.approvedPending),
                                    ("Waiting Approval", viewModel.waitingForApproval)
                                ],
                                onRefresh: {
                                    await viewModel.fetchWorkOrders(profile: profile)
                                },
                                profile: profile
                            )
                        ) {
                            SummaryCardView(
                                title: "PENDING",
                                icon: "clock.fill",
                                count: viewModel.waitingForApproval.count +
                                viewModel.approvedPending.count,
                                tintColor: .orange,
                                backgroundColor: Color(uiColor: .systemBackground)
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(
                            destination: FilteredWorkOrdersView(
                                title: "Completed Orders",
                                sections: [
                                    ("", viewModel.completedOrders)
                                ],
                                onRefresh: {
                                    await viewModel.fetchWorkOrders(profile: profile)
                                },
                                profile: profile
                            )
                        ) {
                            SummaryCardView(
                                title: "COMPLETED",
                                icon: "checkmark.circle.fill",
                                count: viewModel.completedOrders.count,
                                tintColor: .blue,
                                backgroundColor: Color(uiColor: .systemBackground)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top,10)
                    .fixedSize(horizontal: false, vertical: true)


                    // MARK: In Progress
                    VStack(alignment: .leading, spacing: 16) {

                        Text("IN PROGRESS TASKS")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .tracking(1)
                            .padding(.top,8)

                        if viewModel.isLoading &&
                            viewModel.inProgressOrders.isEmpty {

                            ProgressView("Fetching Orders...")
                                .frame(maxWidth: .infinity)
                                .padding()

                        } else if viewModel.inProgressOrders.isEmpty {

                            Text("No tasks currently in progress.")
                                .foregroundColor(.secondary)
                                .padding()

                        } else {

                            VStack(spacing:12) {
                                ForEach(
                                    viewModel.inProgressOrders,
                                    id: \.workOrderId
                                ) { order in

                                    Button {
                                        selectedDetailOrder = order
                                    } label: {
                                        WorkOrderRowView(
                                            workOrder: order,
                                            showStatus: false,
                                            isLargeTitle: true,
                                            onViewReport: {
                                                selectedReportOrder = order
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal,16)
            }

            .navigationTitle("Work Orders")
            .background(Color(uiColor: .systemGroupedBackground))

            .toolbar {

                ToolbarItem(placement: .navigationBarTrailing) {

                    NavigationLink(
                        destination: MaintenanceNotificationsView(
                            unreadCount: $unreadNotificationCount
                        )
                    ) {

                        ZStack(alignment: .topTrailing) {

                            Image(systemName: "bell")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex:"#A3352A"))

                            if unreadNotificationCount > 0 {
                                Text("\(unreadNotificationCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -2)
                            }
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName:"person.circle.fill")
                            .font(.title3)
                            .foregroundColor(Color(hex:"#A3352A"))
                    }
                }
            }

            // MARK: Real-Time & Auto-Fetch
            .task {
                // 1. Fetch fresh data immediately when the view appears
                await viewModel.fetchWorkOrders(profile: profile)
                await fetchUnreadCount()

                // 2. Setup Supabase Realtime Listener
                let channel = SupabaseManager.shared.client.channel("work_orders_realtime")
                let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "work_orders")

                await channel.subscribe()

                // 3. Listen for changes in the background
                for await _ in changes {
                    print("📡 Supabase Database updated! Refreshing UI instantly...")
                    await viewModel.fetchWorkOrders(profile: profile)
                    await fetchUnreadCount()
                }
            }

            .refreshable {
                await viewModel.fetchWorkOrders(profile: profile)
                await fetchUnreadCount()
            }

            // MARK: Floating Add Button
            .overlay(alignment: .bottomTrailing) {

                NavigationLink(destination: AddEditWorkOrderView(maintenancePersonnelId: profile?.userId)
                    .onDisappear {
                        // Fallback: Force refresh precisely when the Add screen closes
                        Task {
                            await viewModel.fetchWorkOrders(profile: profile)
                            await fetchUnreadCount()
                        }
                    }
                ) {
                    Image(systemName:"plus")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width:60,height:60)
                        .background(Color(hex:"#A3352A"))
                        .clipShape(Circle())
                        .shadow(
                            color: .black.opacity(0.2),
                            radius:6,
                            x:0,
                            y:4
                        )
                }
                .padding(.trailing,24)
                .padding(.bottom,24)
            }

            .sheet(
                item: $selectedDetailOrder,
                onDismiss: {
                    Task {
                        try? await Task.sleep(
                            nanoseconds: 500_000_000
                        )
                        await viewModel.fetchWorkOrders(profile: profile)
                    }
                }
            ) { order in
                NavigationStack {
                    WorkOrderDetailView(workOrder: order)
                }
            }

            .sheet(
                item: $selectedReportOrder,
                onDismiss: {
                    Task {
                        try? await Task.sleep(
                            nanoseconds: 500_000_000
                        )
                        await viewModel.fetchWorkOrders(profile: profile)
                    }
                }
            ) { order in
                WorkOrderCompletionReportView(workOrder: order)
            }

            .sheet(isPresented: $showingProfile) {
                MaintenanceProfileView(
                    profile: profile,
                    onSignOut: onSignOut
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(\.locale, .init(identifier: selectedLanguage))
            }
        }
    }

    // MARK: Functions belong inside the View
    private func fetchUnreadCount() async {

        do {
            let session =
            try await SupabaseManager.shared
                .client.auth.session

            let currentUserId = session.user.id

            let response =
            try await SupabaseManager.shared.client
                .from("notifications")
                .select(
                    "id",
                    head: true,
                    count: .exact
                )
                .eq(
                    "recipient_id",
                    value: currentUserId.uuidString
                )
                .eq(
                    "is_read",
                    value: false
                )
                .execute()

            await MainActor.run {
                unreadNotificationCount =
                response.count ?? 0
            }

        } catch {
            print(error)
        }
    }
}

struct FilteredWorkOrdersView: View {
    let title: String
    let sections: [(header: String, orders: [WorkOrder])]
    var onRefresh: (() async -> Void)? = nil
    let profile: UserProfile?
    
    @State private var selectedDetailOrder: WorkOrder?
    @State private var selectedReportOrder: WorkOrder?
    
    // Controls the segmented picker
    @State private var selectedTabIndex: Int = 0
    
    @StateObject private var localViewModel = WorkOrderViewModel()
    
    // 👇 NEW: State for Alert and Instant UI hiding
    @State private var orderToDelete: WorkOrder? = nil
    @State private var deletedOrderIds: Set<UUID> = []
    
    var isEmpty: Bool {
        sections.allSatisfy { $0.orders.isEmpty }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Segmented Control
            if sections.count > 1 {
                Picker("Category", selection: $selectedTabIndex) {
                    ForEach(0..<sections.count, id: \.self) { index in
                        Text(sections[index].header).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            
            // MARK: - List Content
            if isEmpty {
                Text("No orders in this category.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                Spacer()
            } else {
                let currentSection = sections[sections.count > 1 ? selectedTabIndex : 0]
                
                // 👇 FIX: Instantly filter out items the user just swiped to delete
                let visibleOrders = currentSection.orders.filter { !deletedOrderIds.contains($0.workOrderId) }
                
                if visibleOrders.isEmpty {
                    Text("No orders in \(currentSection.header.lowercased()).")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                    Spacer()
                } else {
                    List {
                        ForEach(visibleOrders, id: \.workOrderId) { order in
                            Button(action: {
                                selectedDetailOrder = order
                            }) {
                                WorkOrderRowView(
                                    workOrder: order,
                                    showStatus: false,
                                    isLargeTitle: false,
                                    onViewReport: {
                                        selectedReportOrder = order
                                    }
                                )
                                .opacity(!order.isApproved && order.status == .pending ? 0.6 : 1.0)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            
                            // 👇 CHANGED: allowsFullSwipe is false so they are forced to see the alert
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if order.status != .inProgress {
                                    Button(role: .destructive) {
                                        // Trigger the confirmation alert
                                        orderToDelete = order
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    // 👇 NEW: The Confirmation Alert
                    .alert("Delete Work Order", isPresented: Binding(
                        get: { orderToDelete != nil },
                        set: { if !$0 { orderToDelete = nil } }
                    ), presenting: orderToDelete) { order in
                        Button("Delete", role: .destructive) {
                            // 1. Instantly hide it from the UI so it doesn't "ghost"
                            deletedOrderIds.insert(order.workOrderId)
                            
                            Task {
                                do {
                                    // 2. Delete it from the database
                                    try await localViewModel.deleteWorkOrder(order.workOrderId)
                                    // 3. Refresh the parent views in the background
                                    await onRefresh?()
                                } catch {
                                    print("🚨 Supabase Delete Failed: \(error)")
                                    // 👇 FIX: If the DB blocked the delete, put it back on the UI!
                                    await MainActor.run {
                                        deletedOrderIds.remove(order.workOrderId)
                                    }
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {
                            orderToDelete = nil
                        }
                    } message: { order in
                        Text("Are you sure you want to delete this work order? This action cannot be undone.")
                    }
                }
            }
        }
        .navigationTitle(title)
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(item: $selectedDetailOrder, onDismiss: {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await onRefresh?()
            }
        }) { order in
            NavigationStack {
                WorkOrderDetailView(workOrder: order)
            }
        }
        .sheet(item: $selectedReportOrder, onDismiss: {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await onRefresh?()
            }
        }) { order in
            WorkOrderCompletionReportView(workOrder: order)
        }
    }
}


// MARK: - Summary Card Subview
struct SummaryCardView: View {
    let title: String
    let icon: String
    let count: Int
    let tintColor: Color
    let backgroundColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))

                Text(title)
                    .font(.system(size: 14, weight: .bold))

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(tintColor.opacity(0.5))
            }
            .foregroundColor(tintColor)

            Text("\(count)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Work Order List Row
struct WorkOrderRowView: View {
    let workOrder: WorkOrder
    var showStatus: Bool
    var isLargeTitle: Bool
    var onViewReport: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {

                // Vehicle Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBackgroundColor)
                        .frame(width: 50, height: 50)

                    // UPDATED: Safely unwrap the joined vehicleType or fallback to a car
                    Image(systemName: workOrder.vehicle?.vehicleType?.sfSymbol ?? "car.fill")
                        .foregroundColor(iconColor)
                        .font(.title2)
                }

                // Text Content
                if workOrder.status == .completed {
                    RowTextLinesCompleted(workOrder: workOrder) // Note: Make sure to update the inside of this view too!
                } else {
                    RowTextLinesDefault(workOrder: workOrder, showStatus: showStatus, isLargeTitle: isLargeTitle) // Note: Update this too!
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(Color.gray.opacity(0.4))
            }
            .padding()

            if workOrder.status == .completed {
                ViewReportButtonView(action: {
                    onViewReport?()
                })
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // UPDATED: Safe fallbacks
    private var iconColor: Color { workOrder.vehicle?.vehicleType?.color ?? .blue }
    private var iconBackgroundColor: Color { iconColor.opacity(0.1) }
}

// MARK: - DEFAULT Row Content (Pending / In Progress)
struct RowTextLinesDefault: View {
    let workOrder: WorkOrder
    var showStatus: Bool
    var isLargeTitle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(workOrder.issueTitle)
                    .font(isLargeTitle ? .headline : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()
                PriorityTagView(priority: workOrder.priority)
            }

            // UPDATED: Pulling plate and vehicle name safely from the joined vehicle object
            Text("\(workOrder.vehicle?.numberPlate ?? "N/A") • \(workOrder.vehicle?.vehicleName ?? "Fleet Vehicle")")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            if showStatus {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(workOrder.status.rawValue.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    private var statusColor: Color {
        switch workOrder.status {
        case .pending: return .orange
        case .inProgress: return .green
        case .completed: return .blue
        case .cancelled: return .red
        }
    }
}

// MARK: - COMPLETED Row Content
struct RowTextLinesCompleted: View {
    let workOrder: WorkOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("WO-\(workOrder.workOrderId.uuidString.prefix(4).uppercased())")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Text("DONE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .systemGray5))
                    .clipShape(Capsule())
            }

            // UPDATED: Pulling vehicle name safely from the joined vehicle object
            Text(workOrder.vehicle?.vehicleName ?? "Fleet Vehicle")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(workOrder.issueTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - View Report Button
struct ViewReportButtonView: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center) {
                Spacer()
                Image(systemName: "doc.text.fill")
                    .font(.subheadline.bold())

                Text("View Report")
                    .font(.subheadline.bold())
                Spacer()
            }
            .foregroundColor(.blue)
            .padding(.vertical, 12)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Priority Tag Component
struct PriorityTagView: View {
    let priority: WorkOrderPriority

    var body: some View {
        Text(priority.rawValue.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityBackgroundColor)
            .foregroundColor(priorityTextColor)
            .clipShape(Capsule())
    }

    private var priorityBackgroundColor: Color {
        switch priority {
        case .low: return Color.green.opacity(0.1)
        case .medium: return Color.orange.opacity(0.1)
        case .high, .urgent: return Color.red.opacity(0.1)
        }
    }

    private var priorityTextColor: Color {
        switch priority {
        case .low: return .green
        case .medium: return .orange
        case .high, .urgent: return .red
        }
    }
}

#Preview {
    WorkOrdersView(profile: nil, onSignOut: {})
}
