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
        VStack(alignment: .leading, spacing: 16) {

            // MARK: - Trip ID & Status
            HStack(alignment: .top) {
                Text(trip.displayTripID)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))

                Spacer()

                Text(statusLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(statusColor)
                    .clipShape(Capsule())
            }

            // MARK: - From / To
            HStack(alignment: .top, spacing: 20) {
                // From
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "9CA3AF"))

                    Text(trip.origin ?? "Origin")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // To
                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "9CA3AF"))

                    Text(trip.destination ?? "Destination")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .background(Color(hex: "E5E7EB"))

            // MARK: - Dates
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Placed by")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "9CA3AF"))

                    Text(trip.formattedPlacedDate)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated Date")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "9CA3AF"))

                    Text(trip.formattedEstimatedDate)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // MARK: - Progress Tracker
            progressTracker
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Status Helpers
    private var statusLabel: String {
        switch trip.normalisedStatus {
        case .inTransit, .inProgress: return "Progress"
        case .completed:              return "Delivered"
        case .scheduled:              return "Scheduled"
        case .cancelled:              return "Returned"
        case .unknown:                return "Unknown"
        }
    }

    private var statusColor: Color {
        switch trip.normalisedStatus {
        case .inTransit, .inProgress: return Color(hex: "E8791D")
        case .completed:              return Color(hex: "2E7D32")
        case .scheduled:              return Color(hex: "1565C0")
        case .cancelled:              return Color(hex: "D32F2F")
        case .unknown:                return Color(hex: "757575")
        }
    }

    // MARK: - Progress Tracker
    private var progressTracker: some View {
        let steps = progressSteps
        let activeCount = steps.filter { $0.isActive }.count

        return VStack(spacing: 6) {
            // Dots and lines row
            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    // Dot
                    ZStack {
                        Circle()
                            .fill(step.isActive ? Color(hex: "2D4A2D") : Color.white)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(step.isActive ? Color(hex: "2D4A2D") : Color(hex: "C4C4C4"), lineWidth: 2.5)
                            )

                        if step.isActive {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                        }
                    }

                    // Line between dots (not after the last dot)
                    if index < steps.count - 1 {
                        let isLineActive = index + 1 < activeCount
                        
                        GeometryReader { geo in
                            let lineY = geo.size.height / 2

                            if isLineActive {
                                // Solid active line
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: lineY))
                                    path.addLine(to: CGPoint(x: geo.size.width, y: lineY))
                                }
                                .stroke(Color(hex: "2D4A2D"), lineWidth: 2.5)
                            } else {
                                // Dashed inactive line
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: lineY))
                                    path.addLine(to: CGPoint(x: geo.size.width, y: lineY))
                                }
                                .stroke(
                                    Color(hex: "C4C4C4"),
                                    style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
                                )
                            }
                        }
                        .frame(height: 18)
                    }
                }
            }

            // Labels row
            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Text(step.label)
                        .font(.system(size: 11, weight: step.isActive ? .semibold : .regular))
                        .foregroundColor(step.isActive ? Color(hex: "2D4A2D") : Color(hex: "9CA3AF"))
                        .frame(maxWidth: index == 0 ? nil : .infinity,
                               alignment: index == 0 ? .leading : (index == steps.count - 1 ? .trailing : .center))

                    if index == 0 {
                        Spacer()
                    }
                }
            }
        }
    }

    private var progressSteps: [ProgressStep] {
        switch trip.normalisedStatus {
        case .scheduled:
            return [
                ProgressStep(label: "Packed", isActive: true),
                ProgressStep(label: "In Transit", isActive: false),
                ProgressStep(label: "Delivered", isActive: false)
            ]
        case .inTransit, .inProgress:
            return [
                ProgressStep(label: "Packed", isActive: true),
                ProgressStep(label: "In Transit", isActive: true),
                ProgressStep(label: "Delivered", isActive: false)
            ]
        case .completed:
            return [
                ProgressStep(label: "Packed", isActive: true),
                ProgressStep(label: "In Transit", isActive: true),
                ProgressStep(label: "Delivered", isActive: true)
            ]
        case .cancelled:
            return [
                ProgressStep(label: "Packed", isActive: true),
                ProgressStep(label: "Returned", isActive: true),
                ProgressStep(label: "Refunded", isActive: false)
            ]
        case .unknown:
            return [
                ProgressStep(label: "Packed", isActive: false),
                ProgressStep(label: "In Transit", isActive: false),
                ProgressStep(label: "Delivered", isActive: false)
            ]
        }
    }
}

struct ProgressStep {
    let label: String
    let isActive: Bool
}
