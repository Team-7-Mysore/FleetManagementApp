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
                    NavigationLink(destination: MaintenanceNotificationsView()) {
                        
                        ZStack(alignment: .topTrailing) {
                            
                            Image(systemName: "bell")
                                .font(.headline)
                                .foregroundColor(Color(hex:"#A3352A"))
                            
                            if unreadNotificationCount > 0 {
                                
                                Text("\(unreadNotificationCount)")
                                    .font(.system(size:10, weight:.bold))
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(.red)
                                    .clipShape(Circle())
                                    .offset(x:8,y:-6)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName:"person.circle")
                            .font(.title3)
                            .foregroundColor(Color(hex:"#A3352A"))
                    }
                }
            }
            
            .task {
                if viewModel.workOrders.isEmpty {
                    await viewModel.fetchWorkOrders(profile: profile)
                }
                
                await fetchUnreadCount()
            }
            
            .refreshable {
                await viewModel.fetchWorkOrders(profile: profile)
                await fetchUnreadCount()
            }
            
            // MARK: Floating Add Button
            .overlay(alignment: .bottomTrailing) {
                
                NavigationLink(destination: AddEditWorkOrderView()) {
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
            }
        }
    }
    
    
    // MARK: Functions belong inside the View
    private func fetchUnreadCount() async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("notifications")
                .select("id", head: true, count: .exact)
                .eq("is_read", value: false)
                .execute()
            
            await MainActor.run {
                unreadNotificationCount = response.count ?? 0
            }
            
        } catch {
            print("🚨 Error fetching unread count: \(error)")
        }
    }
}

struct FilteredWorkOrdersView: View {
    let title: String
    let sections: [(header: String, orders: [WorkOrder])]
    var onRefresh: (() async -> Void)? = nil
    let profile: UserProfile? // Added so we can pass it down to WorkOrderDetailView
    
    @State private var selectedDetailOrder: WorkOrder?
    @State private var selectedReportOrder: WorkOrder?
    
    // Controls the segmented picker
    @State private var selectedTabIndex: Int = 0
    
    var isEmpty: Bool {
        sections.allSatisfy { $0.orders.isEmpty }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Segmented Control (Placed naturally under Large Title)
                if sections.count > 1 {
                    Picker("Category", selection: $selectedTabIndex) {
                        ForEach(0..<sections.count, id: \.self) { index in
                            Text(sections[index].header).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                
                // MARK: - List Content
                VStack(alignment: .leading, spacing: 16) {
                    if isEmpty {
                        Text("No orders in this category.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        // Extract the currently active section
                        let currentSection = sections[sections.count > 1 ? selectedTabIndex : 0]
                        
                        if currentSection.orders.isEmpty {
                            Text("No orders in \(currentSection.header.lowercased()).")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(currentSection.orders, id: \.workOrderId) { order in
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
                                        // Visual cue: fade out if waiting for approval
                                        .opacity(!order.isApproved && order.status == .pending ? 0.6 : 1.0)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 16)
        }
        .navigationTitle(title) // <--- Restored native iOS Large Title behavior!
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
