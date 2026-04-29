//
//  AllTripCardView.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 16/04/26.
//

import SwiftUI

struct AllTripCardView: View {
    let trip: Trip

    var body: some View {
        NavigationLink(destination: FleetManagerTripDetailView(trip: trip)) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row - Route name and status badge
                HStack(alignment: .top) {
                    Text(trip.tripNameText)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    statusBadge
                }
                
                // Bottom row - Route details
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.originText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.destinationText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusBadge: some View {
        Text(trip.normalisedStatus.displayTitle)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch trip.normalisedStatus {
        case .inTransit:  return Color(hex: "#F59E0B")  // Amber
        case .inProgress: return Color(hex: "#3B82F6")  // Blue
        case .scheduled:  return Color(hex: "#8B5CF6")  // Purple
        case .completed:  return Color(hex: "#10B981")  // Emerald
        case .cancelled:  return Color(hex: "#EF4444")  // Red
        default:          return Color(.systemGray)
        }
    }
}
