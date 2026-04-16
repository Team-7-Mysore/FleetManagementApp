import Foundation

// MARK: - Trip Service
final class TripService {
    static let shared = TripService()
    private let store = MockDataStore.shared

    private init() {}

    func fetchTrips(forDriver driverId: UUID) -> [Trip] {
        store.trips.filter { $0.driverId == driverId }
            .sorted { $0.scheduledStartTime > $1.scheduledStartTime }
    }

    func activeTrip(forDriver driverId: UUID) -> Trip? {
        store.trips.first { $0.driverId == driverId && $0.status == .inProgress }
    }

    func upcomingTrips(forDriver driverId: UUID) -> [Trip] {
        store.trips.filter { $0.driverId == driverId && $0.status == .planned }
            .sorted { $0.scheduledStartTime < $1.scheduledStartTime }
    }

    func completedTrips(forDriver driverId: UUID) -> [Trip] {
        store.trips.filter { $0.driverId == driverId && $0.status == .completed }
            .sorted { ($0.endTime ?? $0.scheduledStartTime) > ($1.endTime ?? $1.scheduledStartTime) }
    }

    func startTrip(id: UUID) {
        guard let index = store.trips.firstIndex(where: { $0.id == id }) else { return }
        store.trips[index].status = .inProgress
        store.trips[index].startTime = Date()
    }

    func endTrip(id: UUID, distance: Double, fuelUsed: Double) {
        guard let index = store.trips.firstIndex(where: { $0.id == id }) else { return }
        store.trips[index].status = .completed
        store.trips[index].endTime = Date()
        store.trips[index].distance = distance
        store.trips[index].fuelUsed = fuelUsed
    }

    func cancelTrip(id: UUID) {
        guard let index = store.trips.firstIndex(where: { $0.id == id }) else { return }
        store.trips[index].status = .cancelled
    }

    func todayTrips(forDriver driverId: UUID) -> [Trip] {
        let cal = Calendar.current
        return store.trips.filter { trip in
            trip.driverId == driverId &&
            cal.isDateInToday(trip.scheduledStartTime) &&
            (trip.status == .planned || trip.status == .inProgress)
        }.sorted { $0.scheduledStartTime < $1.scheduledStartTime }
    }

    // MARK: - Statistics
    func totalTrips(forDriver driverId: UUID) -> Int {
        store.trips.filter { $0.driverId == driverId }.count
    }

    func totalMiles(forDriver driverId: UUID) -> Double {
        store.trips
            .filter { $0.driverId == driverId && $0.status == .completed }
            .reduce(0) { $0 + $1.distance }
    }

    func averageDistance(forDriver driverId: UUID) -> Double {
        let completed = store.trips.filter { $0.driverId == driverId && $0.status == .completed }
        guard !completed.isEmpty else { return 0 }
        return completed.reduce(0) { $0 + $1.distance } / Double(completed.count)
    }
}
