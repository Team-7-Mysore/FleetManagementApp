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
            VStack(alignment: .leading, spacing: 8) {
                // Top row - Route name and status badge
                HStack {
                    Text(trip.tripNameText)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    statusBadge
                }
                
                // Bottom row - Route details
                HStack(spacing: 6) {
                    Text(trip.originText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .layoutPriority(1)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 2)
                    
                    Text(trip.destinationText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    private var statusBadge: some View {
        Text(trip.normalisedStatus.displayTitle)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch trip.normalisedStatus {
        case .inTransit:
            return Color.orange
        case .inProgress:
            return Color.green
        case .scheduled:
            return Color.blue
        case .completed:
            return Color.green
        case .cancelled:
            return Color.red
        default:
            return Color.gray
        }
    }
}

private struct ProgressStep {
    let label: String
    let isActive: Bool
}
