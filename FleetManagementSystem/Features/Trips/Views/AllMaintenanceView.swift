//
//  AllMaintenanceView.swift
//  FleetManagementSystem
//
//  Created by Kiro AI
//

import SwiftUI

struct AllMaintenanceView: View {
    @StateObject private var vm = TripListViewModel()
    @State private var selectedFilter: MaintenanceFilter = .all
    @State private var selectedWorkOrder: WorkOrder? = nil

    enum MaintenanceFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case inProgress = "In Progress"
        case completed = "Completed"
    }

    private var filteredWorkOrders: [WorkOrder] {
        vm.workOrders.filter { workOrder in
            switch selectedFilter {
            case .all:
                return true
            case .pending:
                return workOrder.status == .pending
            case .inProgress:
                return workOrder.status == .inProgress
            case .completed:
                return workOrder.status == .completed
            }
        }
    }

    private var filterTitle: String {
        selectedFilter == .all ? "All Statuses" : selectedFilter.rawValue
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Label(filterTitle, systemImage: "line.3.horizontal.decrease.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(filteredWorkOrders.count)")
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
                        Text("Loading maintenance records…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if filteredWorkOrders.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredWorkOrders) { workOrder in
                        Button(action: {
                            selectedWorkOrder = workOrder
                        }) {
                            MaintenanceVehicleCard(workOrder: workOrder)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            } header: {
                Text("Maintenance Records")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("All Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $selectedFilter) {
                        ForEach(MaintenanceFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task {
            guard vm.workOrders.isEmpty else { return }
            await vm.fetchTrips()
        }
        .refreshable {
            await vm.fetchTrips()
        }
        .sheet(item: $selectedWorkOrder) { workOrder in
            NavigationStack {
                WorkOrderDetailView(workOrder: workOrder)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView(
            "No Maintenance Records",
            systemImage: "wrench.and.screwdriver",
            description: Text("Try a different status filter or refresh to load recent maintenance records.")
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    NavigationStack {
        AllMaintenanceView()
    }
}
