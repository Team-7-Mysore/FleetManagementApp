//
//  AllTripsView.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 16/04/26.
//

import SwiftUI

struct AllTripsView: View {
    @StateObject private var vm = TripListViewModel()
    @State private var selectedFilter: TripFilter = .all

    enum TripFilter: String, CaseIterable {
        case all = "All"
        case inProgress = "In Progress"
        case delivered = "Delivered"
        case returned = "Returned"
        case scheduled = "Scheduled"
    }

    private var filteredTrips: [Trip] {
        let statusFilteredTrips = vm.trips.filter { trip in
            switch selectedFilter {
            case .all:
                return true
            case .inProgress:
                return trip.normalisedStatus == .inTransit || trip.normalisedStatus == .inProgress
            case .delivered:
                return trip.normalisedStatus == .completed
            case .returned:
                return trip.normalisedStatus == .cancelled
            case .scheduled:
                return trip.normalisedStatus == .scheduled
            }
        }

        return statusFilteredTrips.filter { $0.matchesSearch(vm.searchText) }
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
                    Text("\(filteredTrips.count)")
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
                        Text("Loading trips…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if filteredTrips.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredTrips) { trip in
                        AllTripCardView(trip: trip)
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            } header: {
                Text("Trip History")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("All Trips")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $vm.searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search all trips"
        )
        .searchSuggestions {
            ForEach(vm.searchSuggestions, id: \.self) { suggestion in
                Text(suggestion)
                    .searchCompletion(suggestion)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $selectedFilter) {
                        ForEach(TripFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task {
            guard vm.trips.isEmpty else { return }
            await vm.fetchTrips()
        }
        .refreshable {
            await vm.fetchTrips()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: vm.searchText)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        } else {
            ContentUnavailableView(
                "No Trips Found",
                systemImage: "shippingbox",
                description: Text("Try a different status filter or refresh to load recent trips.")
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }
}

#Preview {
    NavigationStack {
        AllTripsView()
    }
}
