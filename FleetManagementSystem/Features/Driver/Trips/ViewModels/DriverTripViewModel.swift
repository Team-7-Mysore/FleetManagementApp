import Foundation
import Combine
import Supabase

// MARK: - Driver Trip ViewModel
@MainActor
final class DriverTripViewModel: ObservableObject {
    @Published private(set) var activeTrip: TripMap?
    @Published private(set) var upcomingTrips: [TripMap] = []
    @Published private(set) var completedTrips: [TripMap] = []
    @Published var selectedFilter: TripFilter = .upcoming
    @Published var upcomingFilterDate: Date?
    @Published var completedFilterDate: Date?
    @Published private(set) var hasLoadedData = false

    private let user: User
    private var driverId: String?
    private var isLoading = false
    private var refreshTimer: Timer?

    enum TripFilter: String, CaseIterable, Identifiable {
        case upcoming   = "Upcoming"
        case completed  = "Completed"
//        case all        = "All"
        var id: String { rawValue }
    }

    init(user: User) {
        self.user = user
    }

    func loadData(forceRefresh: Bool = false) {
        guard !isLoading else { return }
        if !forceRefresh && hasLoadedData { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                // Step 1: Resolve driver_id
                if driverId == nil {
                    let res = try await SupabaseManager.shared.client
                        .from("drivers")
                        .select("driver_id")
                        .eq("user_id", value: user.id)
                        .single()
                        .execute()
                    let data = try JSONDecoder().decode([String: String].self, from: res.data)
                    driverId = data["driver_id"]
                }

                guard let driverId else { return }

                // Step 2: Fetch trips
                let res = try await SupabaseManager.shared.client
                    .from("trips")
                    .select("*")
                    .eq("driver_id", value: driverId)
                    .execute()

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let str = try container.decode(String.self)
                    if let date = BackendDateParser.parse(str) { return date }
                    throw DecodingError.dataCorruptedError(in: container,
                        debugDescription: "Invalid date: \(str)")
                }

                let dtoTrips = try decoder.decode([TripDTO].self, from: res.data)
                let trips = dtoTrips.map { TripMap(dto: $0) }

                self.activeTrip    = trips.first { $0.status == .inProgress }
                self.upcomingTrips = trips.filter { $0.status == .planned }
                    .sorted { $0.scheduledStartTime < $1.scheduledStartTime }
                self.completedTrips = trips.filter { $0.status == .completed }
                    .sorted { ($0.endTime ?? .distantPast) > ($1.endTime ?? .distantPast) }

                self.hasLoadedData = true
            } catch {
                print("❌ DriverTripViewModel loadData error:", error)
            }
        }
    }

    func startAutoRefresh(interval: TimeInterval = 60) {
        guard refreshTimer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.loadData(forceRefresh: true)
            }
        }
        timer.tolerance = 1.0
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    deinit {
        refreshTimer?.invalidate()
    }

    var filteredTrips: [TripMap] {
        switch selectedFilter {
        case .upcoming:
            let source = upcomingTrips + (activeTrip.map { [$0] } ?? [])
            guard let filterDate = upcomingFilterDate else { return source }
            return source.filter { trip in
                Calendar.current.isDate(tripDate(for: trip), inSameDayAs: filterDate)
            }
        case .completed:
            guard let filterDate = completedFilterDate else { return completedTrips }
            return completedTrips.filter { trip in
                Calendar.current.isDate(tripDate(for: trip), inSameDayAs: filterDate)
            }
//        case .all:       return upcomingTrips + completedTrips + (activeTrip.map { [$0] } ?? [])
        }
    }

    private func tripDate(for trip: TripMap) -> Date {
        if trip.status == .completed {
            return trip.endTime ?? trip.startTime ?? trip.scheduledStartTime
        }
        return trip.scheduledStartTime
    }

    func filterDate(for segment: TripFilter) -> Date? {
        switch segment {
        case .upcoming:
            return upcomingFilterDate
        case .completed:
            return completedFilterDate
        }
    }

    func setFilterDate(_ date: Date?, for segment: TripFilter) {
        switch segment {
        case .upcoming:
            upcomingFilterDate = date
        case .completed:
            completedFilterDate = date
        }
    }

    func startTrip(_ trip: TripMap) {
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("trips")
                    .update([
                        "status": "in_progress",
                        "start_time": ISO8601DateFormatter().string(from: Date())
                    ])
                    .eq("trip_id", value: trip.id.uuidString)
                    .execute()
                loadData()
            } catch {
                print("❌ startTrip error:", error)
            }
        }
    }

    func endTrip(_ trip: TripMap) {
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("trips")
                    .update([
                        "status": "completed",
                        "end_time": ISO8601DateFormatter().string(from: Date())
                    ])
                    .eq("trip_id", value: trip.id.uuidString)
                    .execute()

                let emptyID = "00000000-0000-0000-0000-000000000000"
                let vehicleID = trip.vehicleId.uuidString
                if vehicleID != emptyID {
                    do {
                        try await SupabaseManager.shared.client
                            .from("vehicles")
                            .update(["status": "unassigned"])
                            .eq("vehicle_id", value: vehicleID)
                            .execute()
                    } catch {
                        print("⚠️ vehicle unassign update failed:", error)
                    }
                }

                loadData()
            } catch {
                print("❌ endTrip error:", error)
            }
        }
    }

    func cancelTrip(_ trip: TripMap) {
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("trips")
                    .update(["status": "cancelled"])
                    .eq("trip_id", value: trip.id.uuidString)
                    .execute()
                loadData()
            } catch {
                print("❌ cancelTrip error:", error)
            }
        }
    }
}
