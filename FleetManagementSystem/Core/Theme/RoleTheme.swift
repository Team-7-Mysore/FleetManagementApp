import SwiftUI
import UIKit

struct RoleTheme {
    static func accentColor(for role: AppUserRole?) -> Color {
        guard let role = role else { return AppTheme.primaryGreen }
        switch role {
        case .driver:
            return AppTheme.primaryGreen
        case .fleetManager:
            return AppTheme.techBlue
        case .maintenance:
            return Color(hex: "#A3352A")
        }
    }
    
    static func accentUIColor(for role: AppUserRole?) -> UIColor {
        return UIColor(accentColor(for: role))
    }
}
