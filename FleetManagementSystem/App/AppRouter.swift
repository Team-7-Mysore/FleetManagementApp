import Foundation
import Combine
import SwiftUI

// MARK: - App Routes
enum AppRoute: Hashable {
    case activeTrip(TripMap)
    case vehicleInspection(TripMap?, type: InspectionType = .preTrip)
}

// MARK: - App Router
@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()
    var onSignOut: (() async -> Void)?

    func resetPath() {
        path = NavigationPath()
    }

    func signOut() {
        resetPath()

        if let onSignOut {
            Task {
                await onSignOut()
            }
        }
    }
}
