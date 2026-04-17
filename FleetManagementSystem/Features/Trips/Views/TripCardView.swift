//
//  TripCardView.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 16/04/26.
//

import SwiftUI

struct TripCardView: View {
    let trip: Trip

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(statusTint)
                .frame(width: 44, height: 44)
                .background(statusTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.tripNameText)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(trip.displayTripID)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    statusBadge
                }

                Text(trip.routeText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    Label(trip.formattedPickupTime, systemImage: "calendar")
                    Label(trip.normalisedStatus.displayTitle, systemImage: "circle.fill")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private var statusBadge: some View {
        Text(trip.normalisedStatus.displayTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusTint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusTint.opacity(0.14), in: Capsule())
    }

    private var iconName: String {
        switch trip.normalisedStatus {
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "arrow.uturn.backward.circle.fill"
        case .scheduled:
            return "calendar.circle.fill"
        case .inTransit, .inProgress:
            return "truck.box.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private var statusTint: Color {
        switch trip.normalisedStatus {
        case .inTransit, .inProgress:
            return .orange
        case .completed:
            return .green
        case .scheduled:
            return .blue
        case .cancelled:
            return .red
        case .unknown:
            return .secondary
        }
    }
}
