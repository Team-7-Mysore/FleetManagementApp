//AppRouter

import Foundation
import Combine
import SwiftUI

// MARK: - App Routes
enum AppRoute: Hashable {

    case activeTrip(TripMap)
    case vehicleInspection(TripMap?, type: InspectionType)

    // Custom Hashable implementation because associated values include optionals
    func hash(into hasher: inout Hasher) {
        switch self {
        case .activeTrip(let trip):
            hasher.combine(0)
            hasher.combine(trip)
        case .vehicleInspection(let trip, let type):
            hasher.combine(1)
            hasher.combine(trip)
            hasher.combine(type.rawValue)
        }
    }

    static func == (lhs: AppRoute, rhs: AppRoute) -> Bool {
        switch (lhs, rhs) {
        case (.activeTrip(let l), .activeTrip(let r)):
            return l == r
        case (.vehicleInspection(let lt, let li), .vehicleInspection(let rt, let ri)):
            return lt == rt && li == ri
        default:
            return false
        }
    }

//    case activeTrip(Trip)
//    case vehicleInspection(Trip?, type: InspectionType = .preTrip)

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
