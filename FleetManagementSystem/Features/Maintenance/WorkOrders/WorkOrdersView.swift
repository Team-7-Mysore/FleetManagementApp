import SwiftUI

struct WorkOrdersView: View {
    let profile: UserProfile?
    let onSignOut: () async -> Void
    
    // Injecting the ViewModel to get real data silently
    @StateObject private var viewModel = WorkOrderViewModel()
    
    // Modal Presentation States
    @State private var selectedDetailOrder: WorkOrder?
    @State private var selectedReportOrder: WorkOrder?
    @State private var showingAddOrder: Bool = false
    @State private var showingProfile: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: Top Horizontal Cards (Only 2: Pending & Completed)
                    HStack(spacing: 12) {
                        // Pending Card
                        NavigationLink(destination: FilteredWorkOrdersView(
                            title: "Pending Orders",
                            sections: [
                                ("Approved", viewModel.approvedPending), // Index 0 (Default)
                                ("Waiting Approval", viewModel.waitingForApproval) // Index 1
                            ],
                            onRefresh: { await viewModel.fetchWorkOrders() }
                        )) {
                            SummaryCardView(
                                title: "PENDING",
                                icon: "clock.fill",
                                count: viewModel.waitingForApproval.count + viewModel.approvedPending.count,
                                tintColor: .orange,
                                backgroundColor: Color(uiColor: .systemBackground)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Completed Card
                        NavigationLink(destination: FilteredWorkOrdersView(
                            title: "Completed Orders",
                            sections: [
                                ("", viewModel.completedOrders) // Single section hides the segmented control
                            ],
                            onRefresh: { await viewModel.fetchWorkOrders() }
                        )) {
                            SummaryCardView(
                                title: "COMPLETED",
                                icon: "checkmark.circle.fill",
                                count: viewModel.completedOrders.count,
                                tintColor: .blue,
                                backgroundColor: Color(uiColor: .systemBackground)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)
                    
                    // MARK: List / Content Area (In Progress Only)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("IN PROGRESS TASKS")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .tracking(1.0)
                            .padding(.top, 8)
                        
                        if viewModel.isLoading && viewModel.inProgressOrders.isEmpty {
                            ProgressView("Fetching Orders...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if viewModel.inProgressOrders.isEmpty {
                            Text("No tasks currently in progress.")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            VStack(spacing: 12) {
                                ForEach(viewModel.inProgressOrders, id: \.workOrderId) { order in
                                    Button(action: {
                                        selectedDetailOrder = order
                                    }) {
                                        WorkOrderRowView(
                                            workOrder: order,
                                            showStatus: false,
                                            isLargeTitle: true,
                                            onViewReport: {
                                                selectedReportOrder = order
                                            }
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Work Orders")
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: Text("Notifications Placeholder")) {
                        Image(systemName: "bell")
                            .foregroundColor(Color(hex: "#A3352A"))
                    }
                }
                
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingProfile = true
                    }) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                            .foregroundColor(Color(hex: "#A3352A"))
                    }
                }
                
               
            }
            .task {
                if viewModel.workOrders.isEmpty {
                    await viewModel.fetchWorkOrders()
                }
            }
            .refreshable {
                await viewModel.fetchWorkOrders()
            }
            
            // MARK: - Floating Action Button
            .overlay(alignment: .bottomTrailing) {
                Button(action: {
                    showingAddOrder = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color(hex: "#A3352A")) // Deep Red
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 4)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            
            // MARK: - Modals (Sheets)
            .sheet(item: $selectedDetailOrder, onDismiss: {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await viewModel.fetchWorkOrders()
                }
            }) { order in
                NavigationStack {
                    Text("Detail view for WO-\(order.workOrderId.uuidString.prefix(4))")
                    // Replace with your WorkOrderDetailView(workOrder: order)
                }
            }
            .sheet(item: $selectedReportOrder, onDismiss: {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await viewModel.fetchWorkOrders()
                }
            }) { order in
                Text("Report View Placeholder")
                // Replace with WorkOrderCompletionReportView(workOrder: order)
            }
            .sheet(isPresented: $showingAddOrder, onDismiss: {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await viewModel.fetchWorkOrders()
                }
            }) {
                NavigationStack {
                    Text("Add Order View Placeholder")
                    // Replace with AddEditWorkOrderView()
                }
            }
            .sheet(isPresented: $showingProfile) {
                MaintenanceProfileView(profile: profile, onSignOut: onSignOut)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct FilteredWorkOrdersView: View {
    let title: String
    let sections: [(header: String, orders: [WorkOrder])]
    var onRefresh: (() async -> Void)? = nil
    
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
                Text("Detail view for WO-\(order.workOrderId.uuidString.prefix(4))")
                // Replace with WorkOrderDetailView(workOrder: order)
            }
        }
        .sheet(item: $selectedReportOrder, onDismiss: {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await onRefresh?()
            }
        }) { order in
            Text("Report View Placeholder")
            // Replace with WorkOrderCompletionReportView(workOrder: order)
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
                    
                    Image(systemName: workOrder.vehicleType.sfSymbol)
                        .foregroundColor(iconColor)
                        .font(.title2)
                }
                
                // Text Content
                if workOrder.status == .completed {
                    RowTextLinesCompleted(workOrder: workOrder)
                } else {
                    RowTextLinesDefault(workOrder: workOrder, showStatus: showStatus, isLargeTitle: isLargeTitle)
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
    
    private var iconColor: Color { Color.blue } // Note: replace with workOrder.vehicleType.color
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
            
            Text("\(workOrder.fleetUnitId ?? "Unknown") • \(workOrder.vehicleName ?? "Fleet Vehicle")")
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
            
            Text(workOrder.vehicleName ?? "Fleet Vehicle")
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
