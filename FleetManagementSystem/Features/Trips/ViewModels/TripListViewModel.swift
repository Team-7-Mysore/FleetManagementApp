import SwiftUI
import Combine
import Supabase

@MainActor
final class TripListViewModel: ObservableObject {

    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var searchText = ""

    /// Trips that are currently active (in transit or in progress)
    var activeTrips: [Trip] {
        trips.filter {
            let s = $0.normalisedStatus
            return s == .inTransit || s == .inProgress || s == .scheduled
        }
    }

    var activeTripCount: Int { activeTrips.count }

    /// Capacity percentage (ratio of active trips to total)
    var capacityPercent: Int {
        guard !trips.isEmpty else { return 0 }
        return min(Int(Double(activeTrips.count) / Double(trips.count) * 100), 100)
    }

    /// Filtered trips based on search text
    var filteredTrips: [Trip] {
        let base = activeTrips
        guard !searchText.isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter { trip in
            (trip.trip_name?.lowercased().contains(query) ?? false) ||
            (trip.origin?.lowercased().contains(query) ?? false) ||
            (trip.destination?.lowercased().contains(query) ?? false) ||
            (trip.status?.lowercased().contains(query) ?? false) ||
            trip.displayTripID.lowercased().contains(query)
        }
    }

    func fetchTrips() async {
        isLoading = true

        do {
            let response: [Trip] = try await SupabaseManager.shared.client
                .from("trips")
                .select()
                .order("pickup_time", ascending: false)
                .execute()
                .value

            trips = response
            isLoading = false

        } catch {
            print("❌ FetchTrips error: \(error)")
            isLoading = false
        }
    }
}
