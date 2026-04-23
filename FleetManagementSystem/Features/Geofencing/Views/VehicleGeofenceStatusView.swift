//
//  VehicleGeofenceStatusView.swift
//  FleetManagementSystem
//
//  Created by Kiro on 2025
//

import SwiftUI

struct VehicleGeofenceStatusView: View {
    let vehicleId: UUID

    @StateObject private var viewModel = GeofenceViewModel()

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    loadingCard
                } else if let error = viewModel.errorMessage {
                    errorCard(message: error)
                } else {
                    statusContent
                }
            }
            .padding(.horizontal, AppTheme.paddingMedium)
            .padding(.vertical, AppTheme.paddingMedium)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Geofence Status")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadVehicleStatus(for: vehicleId)
            viewModel.subscribeToGeofenceUpdates()
        }
        .onDisappear {
            viewModel.unsubscribe()
        }
    }

    // MARK: - Status Content

    @ViewBuilder
    private var statusContent: some View {
        let statuses = viewModel.vehicleStatuses[vehicleId] ?? []

        if statuses.isEmpty {
            emptyStateCard
        } else {
            activeGeofencesSection(statuses: statuses)
        }
    }

    // MARK: - Active Geofences Section

    private func activeGeofencesSection(statuses: [GeofenceStatus]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Currently Inside (\(statuses.count))")

            VStack(spacing: 0) {
                ForEach(Array(statuses.enumerated()), id: \.element.geofence_id) { index, status in
                    statusRow(status)
                    if index < statuses.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        }
    }

    // MARK: - Status Row

    private func statusRow(_ status: GeofenceStatus) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGreen.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppTheme.primaryGreen)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(status.geofence_name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Since \(formattedTimestamp(status.entry_timestamp))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            StatusBadge(text: "Inside", color: AppTheme.primaryGreen)
        }
        .padding(.horizontal, AppTheme.paddingMedium)
        .padding(.vertical, 12)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Not Inside Any Geofences")
                .font(.headline)
                .foregroundColor(.primary)

            Text("This vehicle is not currently within any monitored geofence boundaries.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.paddingLarge)
        .padding(.horizontal, AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Loading Card

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Loading status…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Error Card

    private func errorCard(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(AppTheme.statusWarning)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VehicleGeofenceStatusView(vehicleId: UUID())
    }
}
