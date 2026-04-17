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
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.tripNameText)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(trip.displayTripID)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(trip.normalisedStatus.displayTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusTint.opacity(0.14), in: Capsule())
            }

            routeBlock

            Divider()

            VStack(spacing: 10) {
                LabeledContent("Pickup") {
                    Text(trip.formattedPickupTime)
                }

                LabeledContent("Estimated Delivery") {
                    Text(trip.formattedEstimatedDate)
                }

                LabeledContent("Status") {
                    Text(trip.normalisedStatus.displayTitle)
                        .foregroundStyle(statusTint)
                }
            }
            .font(.subheadline)

            progressSummary
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private var routeBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Route", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 12) {
                routeNode(title: "From", value: trip.originText, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)

                routeNode(title: "To", value: trip.destinationText, alignment: .trailing)
            }
        }
    }


    private func routeNode(title: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            stepProgressView

            Text(progressLabel)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var stepProgressView: some View {
        let steps = progressSteps
        let activeCount = steps.filter(\.isActive).count

        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Circle()
                        .fill(step.isActive ? stepTint : Color(.systemBackground))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(step.isActive ? stepTint : Color(.systemGray4), lineWidth: 3)
                        )

                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 2)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(index + 1 < activeCount ? stepTint : Color.clear)
                                    .frame(maxWidth: .infinity)
                            }
                            .overlay {
                                dashedConnector(isActive: index + 1 < activeCount)
                            }
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Text(step.label)
                        .font(.caption2.weight(step.isActive ? .semibold : .regular))
                        .foregroundStyle(step.isActive ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : (index == steps.count - 1 ? .trailing : .center))
                }
            }
        }
    }

    private var progressLabel: String {
        switch trip.normalisedStatus {
        case .scheduled:
            return "Trip is scheduled and waiting to start."
        case .inTransit, .inProgress:
            return "Trip is currently active."
        case .completed:
            return "Trip has been delivered successfully."
        case .cancelled:
            return "Trip was returned or cancelled."
        case .unknown:
            return "Status information is unavailable."
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
                ProgressStep(label: "Closed", isActive: false)
            ]
        case .unknown:
            return [
                ProgressStep(label: "Packed", isActive: false),
                ProgressStep(label: "In Transit", isActive: false),
                ProgressStep(label: "Delivered", isActive: false)
            ]
        }
    }

    private func dashedConnector(isActive: Bool) -> some View {
        GeometryReader { geometry in
            Path { path in
                let y = geometry.size.height / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            }
            .stroke(
                isActive ? stepTint : Color(.systemGray4),
                style: StrokeStyle(lineWidth: 2, dash: isActive ? [] : [4, 4])
            )
        }
    }

    private var stepTint: Color {
        switch trip.normalisedStatus {
        case .inTransit, .inProgress, .completed:
            return .green
        case .scheduled:
            return .blue
        case .cancelled:
            return .red
        case .unknown:
            return .secondary
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

private struct ProgressStep {
    let label: String
    let isActive: Bool
}
