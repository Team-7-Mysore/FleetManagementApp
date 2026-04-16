import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.3)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct PriorityBadge: View {
    let priority: String

    private var color: Color {
        switch priority.lowercased() {
        case "critical", "high":
            return AppTheme.statusDanger
        case "medium":
            return AppTheme.statusWarning
        case "low":
            return AppTheme.primaryGreen
        default:
            return .secondary
        }
    }

    var body: some View {
        StatusBadge(text: priority, color: color)
    }
}
