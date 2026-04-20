import SwiftUI

// MARK: - Trip Detail View
struct TripDetailView: View {
    let trip: Trip
    let user: User
    @StateObject private var vm: DriverTripViewModel
    @Environment(\.dismiss) private var dismiss

    init(trip: Trip, user: User) {
        self.trip = trip
        self.user = user
        _vm = StateObject(wrappedValue: DriverTripViewModel(user: user))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Header
                statusHeader

                // Route Card
                routeCard

                // Trip Details
                detailsCard

                // Notes
                if !trip.notes.isEmpty {
                    notesCard
                }

                // Actions
                actionButtons
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.loadData() }
    }

    // MARK: - Status Header
    private var statusHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.endLocation)
                    .font(.title2.weight(.bold))

                StatusBadge(
                    text: trip.status.rawValue,
                    color: statusColor
                )
            }
            Spacer()
            Image(systemName: trip.status.systemImage)
                .font(.largeTitle)
                .foregroundStyle(statusColor)
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - Route Card
    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ROUTE")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            HStack(alignment: .top) {
                VStack(spacing: 4) {
                    Circle()
                        .stroke(AppTheme.primaryGreen, lineWidth: 2)
                        .frame(width: 14, height: 14)
                    Rectangle()
                        .fill(AppTheme.primaryGreen.opacity(0.3))
                        .frame(width: 2, height: 30)
                    Image(systemName: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primaryGreen)
                }

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(trip.startLocation)
                            .font(.subheadline.weight(.semibold))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Destination")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(trip.endLocation)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.leading, 8)

                Spacer()
            }
        }
        .padding(18)
        .cardStyle()
    }

    // MARK: - Details Card
    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(icon: "road.lanes", title: "Distance", value: trip.formattedDistance)
            Divider().padding(.leading, 48)
            detailRow(icon: "clock", title: "Est. Duration", value: trip.formattedETA)
            Divider().padding(.leading, 48)
            detailRow(icon: "calendar", title: "Scheduled",
                      value: trip.scheduledStartTime.formatted(date: .abbreviated, time: .shortened))

            if trip.status == .inProgress || trip.status == .completed {
                if let startTime = trip.startTime {
                    Divider().padding(.leading, 48)
                    detailRow(icon: "play.circle", title: "Started", value: startTime.formatted(date: .omitted, time: .shortened))
                }
            }

            if trip.status == .completed {
                if let endTime = trip.endTime {
                    Divider().padding(.leading, 48)
                    detailRow(icon: "stop.circle", title: "Ended", value: endTime.formatted(date: .omitted, time: .shortened))
                }
            }

            if let fuel = trip.fuelUsed {
                Divider().padding(.leading, 48)
                detailRow(icon: "fuelpump", title: "Fuel Used", value: String(format: "%.1f gal", fuel))
            }
        }
        .cardStyle()
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.primaryGreen)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Notes
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(trip.notes)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardStyle()
    }

    // MARK: - Action Buttons
    @ViewBuilder
    private var actionButtons: some View {
        if trip.status == .inProgress {
            NavigationLink {
                ActiveTripView(trip: trip, user: user)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                    Text("View Active Trip")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(AppTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            }
        }
    }

    private var statusColor: Color {
        switch trip.status {
        case .planned:    return AppTheme.statusInfo
        case .inProgress: return AppTheme.primaryGreen
        case .completed:  return AppTheme.primaryGreen
        case .cancelled:  return AppTheme.statusDanger
        }
    }
}
