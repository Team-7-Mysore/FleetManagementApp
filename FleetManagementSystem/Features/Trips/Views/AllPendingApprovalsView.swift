import SwiftUI

struct AllPendingApprovalsView: View {
    @StateObject private var vm = TripListViewModel()
    @State private var selectedWorkOrder: WorkOrder? = nil

    private var pendingApprovals: [WorkOrder] {
        vm.workOrders.filter { $0.status == .pending && !$0.isApproved }
    }

    var body: some View {
        List {
            // Header row as a regular list row — avoids List header styling issues
            HStack {
                Text("Vehicles in Maintenance")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: AllMaintenanceView()) {
                    Text("View All")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.TechBlue)
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

            Section {
                mainContent
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Pending Approvals")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard vm.workOrders.isEmpty else { return }
            await vm.fetchTrips()
        }
        .refreshable {
            await vm.fetchTrips()
        }
        .sheet(item: $selectedWorkOrder) { workOrder in
            NavigationStack {
                WorkOrderDetailView(workOrder: workOrder, isManagerApprovalMode: true)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if vm.isLoading {
            loadingState
        } else if pendingApprovals.isEmpty {
            emptyState
        } else {
            approvalsList
        }
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Loading approvals…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Pending Approvals",
            systemImage: "checkmark.seal",
            description: Text("All maintenance work orders have been reviewed.")
        )
        .listRowBackground(Color.clear)
    }

    private var approvalsList: some View {
        ForEach(pendingApprovals) { workOrder in
            PendingApprovalCard(
                workOrder: workOrder,
                onApprove: { Task { await vm.approveWorkOrder(workOrder) } },
                onDecline: { Task { await vm.declineWorkOrder(workOrder) } },
                onTap: { selectedWorkOrder = workOrder }
            )
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    Task { await vm.declineWorkOrder(workOrder) }
                } label: { Label("Decline", systemImage: "xmark") }
                .tint(.red)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    Task { await vm.approveWorkOrder(workOrder) }
                } label: { Label("Approve", systemImage: "checkmark") }
                .tint(.green)
            }
        }
    }
}

// MARK: - Pending Approval Card View
struct PendingApprovalCard: View {
    let workOrder: WorkOrder
    let onApprove: () -> Void
    let onDecline: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(workOrder.vehicle?.vehicleName ?? workOrder.vehicle?.numberPlate ?? "Fleet Vehicle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(workOrder.issueTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text(workOrder.priority.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(priorityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor.opacity(0.12))
                        .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var priorityColor: Color {
        switch workOrder.priority {
        case .urgent: return .red
        case .high:   return .orange
        case .medium: return .yellow
        case .low:    return .green
        }
    }
}

#Preview {
    NavigationStack {
        AllPendingApprovalsView()
    }
}
