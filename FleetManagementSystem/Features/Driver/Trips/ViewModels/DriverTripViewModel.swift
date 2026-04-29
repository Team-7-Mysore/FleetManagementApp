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
    @Published var upcomingFilterStartDate: Date?
    @Published var upcomingFilterEndDate: Date?
    @Published var completedFilterStartDate: Date?
    @Published var completedFilterEndDate: Date?
    @Published private(set) var hasLoadedData = false
    
    // Voice intent properties
    @Published var pendingMileage: Double? = nil
    @Published var pendingFuel: Double? = nil

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
            guard let range = upcomingFilterRange() else { return source }
            return filter(source, within: range)
        case .completed:
            guard let range = completedFilterRange() else { return completedTrips }
            return filter(completedTrips, within: range)
//        case .all:       return upcomingTrips + completedTrips + (activeTrip.map { [$0] } ?? [])
        }
    }

    private func filter(_ trips: [TripMap], within range: (start: Date, end: Date)) -> [TripMap] {
        let calendar = Calendar.current
        let rangeStart = calendar.startOfDay(for: range.start)
        let rangeEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: range.end))
            ?? range.end

        return trips.filter { trip in
            let tripDate = tripDate(for: trip)
            return tripDate >= rangeStart && tripDate <= rangeEnd
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
            return upcomingFilterStartDate
        case .completed:
            return completedFilterStartDate
        }
    }

    func setFilterDate(_ date: Date?, for segment: TripFilter) {
        switch segment {
        case .upcoming:
            upcomingFilterStartDate = date
            upcomingFilterEndDate = date
        case .completed:
            completedFilterStartDate = date
            completedFilterEndDate = date
        }
    }

    func upcomingFilterRange() -> (start: Date, end: Date)? {
        guard let start = upcomingFilterStartDate,
              let end = upcomingFilterEndDate else {
            return nil
        }

        let normalizedStart = Calendar.current.startOfDay(for: min(start, end))
        let normalizedEnd = Calendar.current.startOfDay(for: max(start, end))
        return (start: normalizedStart, end: normalizedEnd)
    }

    func setUpcomingFilterRange(start: Date?, end: Date?) {
        guard let start, let end else {
            upcomingFilterStartDate = nil
            upcomingFilterEndDate = nil
            return
        }

        let normalizedStart = Calendar.current.startOfDay(for: min(start, end))
        let normalizedEnd = Calendar.current.startOfDay(for: max(start, end))
        upcomingFilterStartDate = normalizedStart
        upcomingFilterEndDate = normalizedEnd
    }

    func completedFilterRange() -> (start: Date, end: Date)? {
        guard let start = completedFilterStartDate,
              let end = completedFilterEndDate else {
            return nil
        }

        let normalizedStart = Calendar.current.startOfDay(for: min(start, end))
        let normalizedEnd = Calendar.current.startOfDay(for: max(start, end))
        return (start: normalizedStart, end: normalizedEnd)
    }

    func setCompletedFilterRange(start: Date?, end: Date?) {
        guard let start, let end else {
            completedFilterStartDate = nil
            completedFilterEndDate = nil
            return
        }

        let normalizedStart = Calendar.current.startOfDay(for: min(start, end))
        let normalizedEnd = Calendar.current.startOfDay(for: max(start, end))
        completedFilterStartDate = normalizedStart
        completedFilterEndDate = normalizedEnd
    }

    func filterRange(for segment: TripFilter) -> (start: Date, end: Date)? {
        switch segment {
        case .upcoming:
            return upcomingFilterRange()
        case .completed:
            return completedFilterRange()
        }
    }

    func setFilterRange(start: Date?, end: Date?, for segment: TripFilter) {
        switch segment {
        case .upcoming:
            setUpcomingFilterRange(start: start, end: end)
        case .completed:
            setCompletedFilterRange(start: start, end: end)
        }
    }

    func hasActiveFilter(for segment: TripFilter) -> Bool {
        switch segment {
        case .upcoming:
            return upcomingFilterStartDate != nil && upcomingFilterEndDate != nil
        case .completed:
            return completedFilterStartDate != nil && completedFilterEndDate != nil
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
    
    // Voice intent methods
    func storeMileage(_ value: Double?) {
        pendingMileage = value
    }

    func storeFuel(_ value: Double?) {
        pendingFuel = value
    }
}
