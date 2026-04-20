import SwiftUI

// MARK: - Active Trip View
struct ActiveTripView: View {
    let trip: Trip
    let user: User
    @StateObject private var vm: DriverTripViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var elapsedTime: TimeInterval = 0
    @State private var showEndTripConfirmation = false
    @State private var showReportIssue = false
    @State private var timer: Timer?

    init(trip: Trip, user: User) {
        self.trip = trip
        self.user = user
        _vm = StateObject(wrappedValue: DriverTripViewModel(user: user))
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Map Placeholder
            ZStack {
                // Map area
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(.secondarySystemBackground))
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.primaryGreen.opacity(0.3))
                            Text("Route Map")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(trip.startLocation) → \(trip.endLocation)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                // Turn indicator overlay
                VStack {
                    HStack {
                        turnIndicator
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    Spacer()
                }
            }
            .frame(maxHeight: .infinity)

            // MARK: - Bottom Panel
            VStack(spacing: 16) {
                // Trip info bar
                HStack(spacing: 24) {
                    tripInfoItem(value: trip.formattedDistance, label: "Distance")
                    Divider().frame(height: 36)
                    tripInfoItem(value: trip.formattedETA, label: "ETA")
                    Divider().frame(height: 36)
                    tripInfoItem(value: formattedElapsed, label: "Elapsed")
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Action buttons
                HStack(spacing: 12) {
                    Button { showReportIssue = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Report Issue")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.statusDanger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppTheme.statusDanger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button { showEndTripConfirmation = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                            Text("End Trip")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(AppTheme.primaryGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal)

                // Destination bar
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(AppTheme.primaryGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Destination")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(trip.endLocation)
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Active Trip")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("End Trip", isPresented: $showEndTripConfirmation) {
            Button("End Trip", role: .destructive) {
                vm.endTrip(trip)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this trip?")
        }
        .sheet(isPresented: $showReportIssue) {
            ReportIssueView(user: user, vehicle: nil)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    // MARK: - Turn Indicator
    private var turnIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.turn.up.right")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 0) {
                Text("0.3 mi")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                Text("Turn right")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.primaryGreen)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tripInfoItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedElapsed: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        if let startTime = trip.startTime {
            elapsedTime = Date().timeIntervalSince(startTime)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let startTime = trip.startTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
