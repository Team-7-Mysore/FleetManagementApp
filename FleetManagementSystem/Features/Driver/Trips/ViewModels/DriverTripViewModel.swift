import Foundation
import Combine

// MARK: - Driver Trip ViewModel
@MainActor
final class DriverTripViewModel: ObservableObject {
    @Published private(set) var activeTrip: Trip?
    @Published private(set) var upcomingTrips: [Trip] = []
    @Published private(set) var completedTrips: [Trip] = []
    @Published var selectedFilter: TripFilter = .upcoming

    private let user: User
    private let tripService = TripService.shared

    enum TripFilter: String, CaseIterable, Identifiable {
        case upcoming   = "Upcoming"
        case completed  = "Completed"
        case all        = "All"
        var id: String { rawValue }
    }

    init(user: User) {
        self.user = user
    }

    func loadData() {
        activeTrip = tripService.activeTrip(forDriver: user.id)
        upcomingTrips = tripService.upcomingTrips(forDriver: user.id)
        completedTrips = tripService.completedTrips(forDriver: user.id)
    }

    var filteredTrips: [Trip] {
        switch selectedFilter {
        case .upcoming:  return upcomingTrips
        case .completed: return completedTrips
        case .all:       return tripService.fetchTrips(forDriver: user.id)
        }
    }

    func startTrip(_ trip: Trip) {
        tripService.startTrip(id: trip.id)
        loadData()
    }

    func endTrip(_ trip: Trip) {
        tripService.endTrip(id: trip.id, distance: trip.distance, fuelUsed: trip.distance / 18.0)
        loadData()
    }

    func cancelTrip(_ trip: Trip) {
        tripService.cancelTrip(id: trip.id)
        loadData()
    }
}
