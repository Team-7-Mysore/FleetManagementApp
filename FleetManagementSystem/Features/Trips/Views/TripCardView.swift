import SwiftUI

struct TripCardView: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 14) {

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: "calendar")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 8) {

                // Top Row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.trip_name ?? "Trip")
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)

                        Text(trip.displayTripID)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Text(trip.normalisedStatus.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.15))
                        .clipShape(Capsule())
                }

                // Route
                Text("\(trip.origin ?? "") to \(trip.destination ?? "")")
                    .font(.system(size: 14))
                    .foregroundColor(.black)

                // Bottom Row (Aligned)
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        Text(trip.formattedPickupTime)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var statusColor: Color {
        switch trip.normalisedStatus {
        case .inTransit:  return Color(hex: "#F59E0B")  // Amber
        case .inProgress: return Color(hex: "#3B82F6")  // Blue
        case .scheduled:  return Color(hex: "#8B5CF6")  // Purple
        case .completed:  return Color(hex: "#10B981")  // Emerald
        case .cancelled:  return Color(.systemGray)
        case .unknown:    return Color(.systemGray)
        }
    }
}
