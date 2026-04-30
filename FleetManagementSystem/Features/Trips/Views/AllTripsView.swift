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
    @Environment(\.dismiss) var dismiss

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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Filter Status Indicator
                HStack {
                    Label(filterTitle, systemImage: "line.3.horizontal.decrease.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(filteredTrips.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Trip History")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)

                    if vm.isLoading {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Loading trips…")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                    } else if filteredTrips.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTrips) { trip in
                                AllTripCardView(trip: trip)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("All Trips")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                        .foregroundColor(.primary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Status", selection: $selectedFilter) {
                        ForEach(TripFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.body.weight(.semibold))
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                        .foregroundColor(.primary)
                }
            }
        }
        .searchable(
            text: $vm.searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search all trips"
        )
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
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("No results for \"\(vm.searchText)\"")
                    .font(.headline)
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("No Trips Found")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Try a different status filter or refresh to load recent trips.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
