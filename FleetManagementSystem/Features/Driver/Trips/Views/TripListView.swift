import SwiftUI

// MARK: - Trip List View
struct TripListView: View {
    let user: User
    @StateObject private var vm: DriverTripViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(user: User) {
        self.user = user
        _vm = StateObject(wrappedValue: DriverTripViewModel(user: user))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Active Trip Banner
                if let active = vm.activeTrip {
                    NavigationLink {
                        ActiveTripView(trip: active, user: user)
                    } label: {
                        activeTripBanner(active)
                    }
                    .buttonStyle(.plain)
                }

                // Filter Picker
                Picker("Filter", selection: $vm.selectedFilter) {
                    ForEach(DriverTripViewModel.TripFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 4)

                // Trip List
                if vm.filteredTrips.isEmpty {
                    EmptyStateView(
                        icon: "map",
                        title: "No Trips",
                        message: "No \(vm.selectedFilter.rawValue.lowercased()) trips to show."
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.filteredTrips) { trip in
                            NavigationLink {
                                TripDetailView(trip: trip, user: user)
                            } label: {
                                tripCard(trip)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("My Trips")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.loadData()
            vm.startAutoRefresh()
        }
        .onDisappear {
            vm.stopAutoRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                vm.loadData()
            }
        }
        .refreshable {
            vm.loadData()
        }
    }

    // MARK: - Active Trip Banner
    private func activeTripBanner(_ trip: TripMap) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "location.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AppTheme.primaryGreen.opacity(0.8))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Active Trip")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(trip.startLocation) → \(trip.endLocation)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
        .background(
            LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                           startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }

    // MARK: - Trip Card
    private func tripCard(_ trip: TripMap) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor(for: trip.status))
                            .frame(width: 8, height: 8)
                        Text(trip.status.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(statusColor(for: trip.status))
                    }

                    Text(trip.endLocation)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("DIST")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(trip.formattedDistance)
                            .font(.title2.weight(.bold).monospacedDigit())
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("ETA")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(trip.formattedETA)
                            .font(.headline.weight(.semibold).monospacedDigit())
                    }
                }
            }

            HStack(spacing: 16) {
                Label {
                    Text(trip.startLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "circle")
                        .font(.system(size: 6))
                        .foregroundStyle(AppTheme.primaryGreen)
                }

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Label {
                    Text(trip.endLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "mappin")
                        .font(.system(size: 8))
                        .foregroundStyle(AppTheme.primaryGreen)
                }

                Spacer()

                if trip.status == .completed, let startTime = trip.startTime {
                    Text(startTime, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(trip.scheduledStartTime, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func statusColor(for status: TripStatus) -> Color {
        switch status {
        case .planned:    return AppTheme.statusInfo
        case .inProgress: return AppTheme.primaryGreen
        case .completed:  return .secondary
        case .cancelled:  return AppTheme.statusDanger
        }
    }
}
