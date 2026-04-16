//
//  AllTripsView.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 16/04/26.
//

import SwiftUI

struct AllTripsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = TripListViewModel()

    @State private var selectedFilter: TripFilter = .all

    enum TripFilter: String, CaseIterable {
        case all = "All"
        case inProgress = "In Progress"
        case delivered = "Delivered"
        case returned = "Returned"
        case scheduled = "Scheduled"
    }

    var filteredTrips: [Trip] {
        switch selectedFilter {
        case .all:
            return vm.trips
        case .inProgress:
            return vm.trips.filter {
                $0.normalisedStatus == .inTransit || $0.normalisedStatus == .inProgress
            }
        case .delivered:
            return vm.trips.filter { $0.normalisedStatus == .completed }
        case .returned:
            return vm.trips.filter { $0.normalisedStatus == .cancelled }
        case .scheduled:
            return vm.trips.filter { $0.normalisedStatus == .scheduled }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Navigation Bar
            navBar

            // MARK: - Filter Chips
            filterChips

            // MARK: - Trip List
            if vm.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.3)
                Spacer()
            } else if filteredTrips.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredTrips) { trip in
                            AllTripCardView(trip: trip)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Color(hex: "EFEFEF"))
        .navigationBarHidden(true)
        .onAppear {
            Task { await vm.fetchTrips() }
        }
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        ZStack {
            Color(hex: "E8E8E8")

            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.6))
                        .clipShape(Circle())
                }

                Spacer()

                Text("My Deliveries")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))

                Spacer()

                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 56)
    }

    // MARK: - Filter Chips
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TripFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }) {
                        Text(filter.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selectedFilter == filter ? .white : Color(hex: "1A1A2E"))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                selectedFilter == filter
                                    ? Color(hex: "2D4A2D")
                                    : Color.white
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selectedFilter == filter
                                            ? Color.clear
                                            : Color(hex: "D1D5DB"),
                                        lineWidth: 1
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(hex: "E8E8E8"))
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44))
                .foregroundColor(Color(hex: "C4C4C4"))

            Text("No trips found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "6B7280"))

            Text("Try selecting a different filter")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "9CA3AF"))
        }
    }
}

#Preview {
    AllTripsView()
}
