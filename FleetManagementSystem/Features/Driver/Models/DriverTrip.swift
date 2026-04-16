import Foundation

struct DriverTrip: Identifiable, Equatable {
    let id: UUID
    let title: String
    let route: String
    let schedule: String
    let status: DriverTripStatus
    let distance: String
    let eta: String
}

enum DriverTripStatus: String, Equatable {
    case active
    case upcoming
    case completed

    var displayName: String {
        rawValue.capitalized
    }
}
