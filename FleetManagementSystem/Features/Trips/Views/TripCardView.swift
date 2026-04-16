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
        HStack(spacing: 14) {
            // Truck icon circle
            ZStack {
                Circle()
                    .fill(Color(hex: "E8F5E9"))
                    .frame(width: 48, height: 48)

                Image(systemName: "truck.box.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "2E7D32"))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trip.displayTripID)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))

                    Spacer()

                    // Status badge
                    Text(trip.normalisedStatus.label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusForeground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusBackground)
                        .clipShape(Capsule())
                }

                Text("\(trip.origin ?? "Origin") → \(trip.destination ?? "Destination")")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "6B7280"))

                Text(trip.formattedPickupTime)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "9CA3AF"))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Status Colors
    private var statusForeground: Color {
        switch trip.normalisedStatus {
        case .inTransit:  return Color(hex: "D32F2F")
        case .inProgress: return Color(hex: "1565C0")
        case .completed:  return Color(hex: "2E7D32")
        case .scheduled:  return Color(hex: "F57F17")
        case .cancelled:  return Color(hex: "757575")
        case .unknown:    return Color(hex: "757575")
        }
    }

    private var statusBackground: Color {
        switch trip.normalisedStatus {
        case .inTransit:  return Color(hex: "FFEBEE")
        case .inProgress: return Color(hex: "E3F2FD")
        case .completed:  return Color(hex: "E8F5E9")
        case .scheduled:  return Color(hex: "FFF8E1")
        case .cancelled:  return Color(hex: "F5F5F5")
        case .unknown:    return Color(hex: "F5F5F5")
        }
    }
}
