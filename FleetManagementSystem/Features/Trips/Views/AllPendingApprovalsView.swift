import SwiftUI

struct AllPendingApprovalsView: View {
    @StateObject private var vm = TripListViewModel()
    @State private var selectedWorkOrder: WorkOrder? = nil

    /// Work orders that are pending and not yet approved
    private var pendingApprovals: [WorkOrder] {
        vm.workOrders.filter { $0.status == .pending && !$0.isApproved }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Label("Awaiting Approval", systemImage: "clock.badge.exclamationmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(pendingApprovals.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                if vm.isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading approvals…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if pendingApprovals.isEmpty {
                    ContentUnavailableView(
                        "No Pending Approvals",
                        systemImage: "checkmark.seal",
                        description: Text("All maintenance work orders have been reviewed.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(pendingApprovals) { workOrder in
                        PendingApprovalCard(workOrder: workOrder) {
                            Task { await vm.approveWorkOrder(workOrder) }
                        } onDecline: {
                            Task { await vm.declineWorkOrder(workOrder) }
                        } onTap: {
                            selectedWorkOrder = workOrder
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await vm.declineWorkOrder(workOrder) }
                            } label: {
                                Label("Decline", systemImage: "xmark")
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task { await vm.approveWorkOrder(workOrder) }
                            } label: {
                                Label("Approve", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
            } header: {
                Text("Pending Work Orders")
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
}

#Preview {
    NavigationStack {
        AllPendingApprovalsView()
    }
}
