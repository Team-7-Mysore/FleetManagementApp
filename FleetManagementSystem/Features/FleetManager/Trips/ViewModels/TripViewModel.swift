import SwiftUI
import Combine
import Supabase
import MapKit
import CoreLocation

struct TripInsert: Encodable {
    let trip_name: String
    let client_contact: String
    let origin: String
    let destination: String
    let via_points: [String]
    let pickup_time: String
    let start_time: String
    let end_time: String
    let start_location: String
    let end_location: String
    let vehicle_id: UUID
    let driver_id: UUID
    let status: String
}

private struct DriverRecord: Decodable {
    let driver_id: UUID
    let user_id: UUID?
    let license_no: String
    let license_expiry: String
}

private struct UserRecord: Decodable {
    let user_id: UUID
    let name: String
}

private struct RouteRecord: Decodable {
    let route_id: UUID
    let start_location: String?
    let end_location: String?
}

@MainActor
final class TripViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isLoadingAssignments = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published private(set) var availableVehicles: [VehicleAssignmentOption] = []
    @Published private(set) var availableDrivers: [DriverAssignmentOption] = []
    @Published var calculatedDistance: Double?
    @Published var calculatedETA: TimeInterval?
    @Published var isCalculatingRoute = false
    @Published var originCoordinates: CLLocationCoordinate2D?
    @Published var destinationCoordinates: CLLocationCoordinate2D?

    func resetAssignmentOptions() {
        availableVehicles = []
        availableDrivers = []
        if !isLoadingAssignments {
            errorMessage = nil
        }
    }

    func loadAssignmentOptions(
        pickupLocation: String,
        destination: String,
        pickupDate: Date,
        expectedEndDate: Date
    ) async {
        let trimmedPickupLocation = pickupLocation.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPickupLocation.isEmpty else {
            errorMessage = "Enter the pickup location before assigning a vehicle and driver."
            availableVehicles = []
            availableDrivers = []
            return
        }

        guard expectedEndDate > pickupDate else {
            errorMessage = "Expected end time must be after pickup time."
            availableVehicles = []
            availableDrivers = []
            return
        }

        isLoadingAssignments = true
        errorMessage = nil

        do {
            let vehicles: [VehicleAssignmentOption] = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("vehicle_id, number_plate, vehicle_name, vehicle_type, status")
                .execute()
                .value

            let trips: [AssignmentTripRecord]
            do {
                trips = try await SupabaseManager.shared.client
                    .from("trips")
                    .select("trip_id, vehicle_id, driver_id, route_id, status, start_time, end_time, pickup_time, origin, destination, start_location, end_location")
                    .execute()
                    .value
            } catch {
                trips = []
            }

            let routes: [RouteRecord]
            do {
                routes = try await SupabaseManager.shared.client
                    .from("routes")
                    .select("route_id, start_location, end_location")
                    .execute()
                    .value
            } catch {
                routes = []
            }

            let routesById = Dictionary(uniqueKeysWithValues: routes.map { ($0.route_id, $0) })

            let conflictingTrips = trips.filter { trip in
                blocksAvailability(status: trip.status) && overlaps(
                    existingStart: tripStartDate(from: trip),
                    existingEnd: tripEndDate(from: trip),
                    requestedStart: pickupDate,
                    requestedEnd: expectedEndDate
                )
            }

            let busyVehicleIDs = Set(conflictingTrips.compactMap(\.vehicle_id))

            availableVehicles = vehicles
                .filter(isVehicleEligible)
                .filter { !busyVehicleIDs.contains($0.vehicle_id) }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            do {
                let drivers: [DriverRecord] = try await SupabaseManager.shared.client
                    .from("drivers")
                    .select("driver_id, user_id, license_no, license_expiry")
                    .execute()
                    .value

                let users: [UserRecord]
                do {
                    users = try await SupabaseManager.shared.client
                        .from("users")
                        .select("user_id, name")
                        .execute()
                        .value
                } catch {
                    users = []
                }

                let busyDriverIDs = Set(conflictingTrips.compactMap(\.driver_id))
                let usersByID = Dictionary(uniqueKeysWithValues: users.map { ($0.user_id, $0) })
                let normalizedOrigin = normalizeLocation(pickupLocation)
                let normalizedDestination = normalizeLocation(destination)

                availableDrivers = drivers
                    .filter { hasValidLicenseExpiry($0.license_expiry, relativeTo: pickupDate) }
                    .filter { !busyDriverIDs.contains($0.driver_id) }
                    .map { driver in
                        let user = driver.user_id.flatMap { usersByID[$0] }
                        let inferredLocation = inferredDriverLocation(for: driver.driver_id, trips: trips)
                        let routeExperienceCount = routeExperienceCount(
                            for: driver.driver_id,
                            trips: trips,
                            routesById: routesById,
                            normalizedOrigin: normalizedOrigin,
                            normalizedDestination: normalizedDestination
                        )
                        return DriverAssignmentOption(
                            id: driver.driver_id,
                            userID: driver.user_id,
                            name: user?.name ?? "Driver \(driver.driver_id.uuidString.prefix(4))",
                            licenseNumber: driver.license_no,
                            licenseExpiry: driver.license_expiry,
                            locationHint: inferredLocation.map { "Near \($0)" },
                            routeExperienceCount: routeExperienceCount,
                            isRecommended: false
                        )
                    }

                availableDrivers = applyRouteRecommendation(to: availableDrivers)
#if DEBUG
                debugLogRouteRecommendation(
                    pickupLocation: pickupLocation,
                    destination: destination,
                    normalizedOrigin: normalizedOrigin,
                    normalizedDestination: normalizedDestination,
                    trips: trips,
                    routesById: routesById,
                    drivers: availableDrivers
                )
#endif
            } catch {
                availableDrivers = []
            }

            if availableVehicles.isEmpty {
                errorMessage = "No vehicles are currently available for this trip window."
            } else if availableDrivers.isEmpty {
                errorMessage = "Vehicles loaded, but no drivers matched the current constraints."
            }

        } catch {
            errorMessage = error.localizedDescription
            availableVehicles = []
            availableDrivers = []
        }

        isLoadingAssignments = false
    }

    func calculateRoute(
        origin: String,
        originCoord: CLLocationCoordinate2D?,
        destination: String,
        destinationCoord: CLLocationCoordinate2D?,
        waypoints: [CLLocationCoordinate2D] = []
    ) async {
        guard !origin.isEmpty, !destination.isEmpty else {
            calculatedDistance = nil
            calculatedETA = nil
            originCoordinates = nil
            destinationCoordinates = nil
            return
        }

        isCalculatingRoute = true
        
        do {
            // 1. Resolve origin coordinate
            let finalOrigin: CLLocationCoordinate2D
            if let originCoord = originCoord {
                finalOrigin = originCoord
            } else {
                let placemark = try await geocodeAddress(origin)
                guard let coord = placemark.location?.coordinate else { throw NSError(domain: "TripVM", code: -1) }
                finalOrigin = coord
            }
            self.originCoordinates = finalOrigin

            // 2. Resolve destination coordinate
            let finalDest: CLLocationCoordinate2D
            if let destinationCoord = destinationCoord {
                finalDest = destinationCoord
            } else {
                let placemark = try await geocodeAddress(destination)
                guard let coord = placemark.location?.coordinate else { throw NSError(domain: "TripVM", code: -1) }
                finalDest = coord
            }
            self.destinationCoordinates = finalDest

            // 3. Chain segments to handle multiple waypoints and get total distance/ETA
            let allPoints = [finalOrigin] + waypoints + [finalDest]
            var totalDistance: Double = 0
            var totalETA: TimeInterval = 0
            
            for i in 0..<(allPoints.count - 1) {
                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(coordinate: allPoints[i]))
                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: allPoints[i+1]))
                request.transportType = .automobile
                
                let response = try await MKDirections(request: request).calculate()
                if let route = response.routes.first {
                    totalDistance += route.distance
                    totalETA += route.expectedTravelTime
                }
            }

            self.calculatedDistance = totalDistance / 1000.0 // km
            self.calculatedETA = totalETA
            
            print("✅ Route calculated with \(waypoints.count) waypoints:")
            print("   Distance: \(String(format: "%.2f", calculatedDistance ?? 0)) km")
            print("   ETA: \(String(format: "%.0f", (calculatedETA ?? 0) / 60)) minutes")

        } catch {
            print("❌ Failed to calculate route: \(error.localizedDescription)")
            calculatedDistance = nil
            calculatedETA = nil
        }
        
        isCalculatingRoute = false
    }

    private func geocodeAddress(_ address: String) async throws -> CLPlacemark {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(address)
        guard let placemark = placemarks.first else {
            throw NSError(domain: "TripViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No location found for address"])
        }
        return placemark
    }

    func createTrip(
        tripName: String,
        clientContact: String,
        origin: String,
        destination: String,
        viaPoints: [String],
        pickupDate: Date,
        expectedEndDate: Date,
        vehicleID: UUID?,
        driverID: UUID?,
        distance: Double?,
        fleetManagerId: UUID?
    ) async {

        if tripName.isEmpty || origin.isEmpty || destination.isEmpty {
            errorMessage = "Required fields missing"
            return
        }

        guard let vehicleID else {
            errorMessage = "Select an available vehicle"
            return
        }

        guard let driverID else {
            errorMessage = "Select an available driver"
            return
        }

        guard expectedEndDate > pickupDate else {
            errorMessage = "Expected end time must be after pickup time"
            return
        }

        isLoading = true
        errorMessage = nil

        // Convert local dates to UTC for Supabase
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        let pickupISODate = formatter.string(from: pickupDate)
        let endISODate = formatter.string(from: expectedEndDate)

        do {
            // Build the insert data
            struct TripInsertWithDistance: Encodable {
                let trip_name: String
                let client_contact: String
                let origin: String
                let destination: String
                let via_points: [String]
                let pickup_time: String
                let start_time: String
                let end_time: String
                let start_location: String
                let end_location: String
                let vehicle_id: UUID
                let driver_id: UUID
                let status: String
                let distance_travelled: Double?
                let fleet_manager_id: UUID?
                let origin_latitude: Double?
                let origin_longitude: Double?
                let destination_latitude: Double?
                let destination_longitude: Double?
                let eta: Double?
            }
            
            let tripData = TripInsertWithDistance(
                trip_name: tripName,
                client_contact: clientContact,
                origin: origin,
                destination: destination,
                via_points: viaPoints,
                pickup_time: pickupISODate,
                start_time: pickupISODate,
                end_time: endISODate,
                start_location: origin,
                end_location: destination,
                vehicle_id: vehicleID,
                driver_id: driverID,
                status: "assigned",
                distance_travelled: distance,
                fleet_manager_id: fleetManagerId,
                origin_latitude: originCoordinates?.latitude,
                origin_longitude: originCoordinates?.longitude,
                destination_latitude: destinationCoordinates?.latitude,
                destination_longitude: destinationCoordinates?.longitude,
                eta: calculatedETA.map { $0 / 60.0 } // Convert seconds to minutes
            )
            
            try await SupabaseManager.shared.client
                .from("trips")
                .insert(tripData)
                .execute()

            print("✅ Trip created successfully in Supabase")
            successMessage = "Trip created successfully!"
            isLoading = false

        } catch {
            print("❌ Failed to create trip: \(error.localizedDescription)")
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func isVehicleEligible(_ vehicle: VehicleAssignmentOption) -> Bool {
        guard let status = vehicle.status?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
            return true
        }
        return status != "maintenance" && status != "inactive"
    }

    private func hasValidLicenseExpiry(_ rawDate: String, relativeTo referenceDate: Date) -> Bool {
        guard let expiryDate = parseDatabaseDate(rawDate) else {
            return false
        }
        return expiryDate >= Calendar.current.startOfDay(for: referenceDate)
    }

    private func blocksAvailability(status: String?) -> Bool {
        guard let status = status?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        // These statuses indicate the driver/vehicle is committed to a trip
        return ["assigned", "scheduled", "pending", "in_progress", "in progress", "in_transit", "in transit", "planned", "active"].contains(status)
    }

    private func overlaps(
        existingStart: Date?,
        existingEnd: Date?,
        requestedStart: Date,
        requestedEnd: Date
    ) -> Bool {
        guard let existingStart else { return false }
        
        // Use +4h if no end time, otherwise use actual end time.
        // Add a 30 minute (1800s) buffer for turnover/rest/cleaning.
        let baseEnd = existingEnd ?? Calendar.current.date(byAdding: .hour, value: 4, to: existingStart) ?? existingStart
        let bufferedExistingEnd = baseEnd.addingTimeInterval(1800) 
        
        // Standard overlap: (StartA < EndB) AND (EndA > StartB)
        return existingStart < requestedEnd && bufferedExistingEnd > requestedStart
    }

    private func tripStartDate(from trip: AssignmentTripRecord) -> Date? {
        parseDatabaseTimestamp(trip.start_time)
            ?? parseDatabaseTimestamp(trip.pickup_time)
    }

    private func tripEndDate(from trip: AssignmentTripRecord) -> Date? {
        parseDatabaseTimestamp(trip.end_time)
    }

    private func inferredDriverLocation(for driverID: UUID, trips: [AssignmentTripRecord]) -> String? {
        let latestTrip = trips
            .filter { $0.driver_id == driverID }
            .sorted { lhs, rhs in
                let lhsDate = tripEndDate(from: lhs) ?? tripStartDate(from: lhs) ?? .distantPast
                let rhsDate = tripEndDate(from: rhs) ?? tripStartDate(from: rhs) ?? .distantPast
                return lhsDate > rhsDate
            }
            .first

        return latestTrip?.destination
            ?? latestTrip?.end_location
            ?? latestTrip?.origin
            ?? latestTrip?.start_location
    }

    private func isDriverNearPickup(_ driverID: UUID, pickupLocation: String, trips: [AssignmentTripRecord]) -> Bool {
        let normalizedPickupLocation = normalizeLocation(pickupLocation)
        guard !normalizedPickupLocation.isEmpty else { return true }

        guard let inferredLocation = inferredDriverLocation(for: driverID, trips: trips) else {
            return true
        }

        let normalizedDriverLocation = normalizeLocation(inferredLocation)
        guard !normalizedDriverLocation.isEmpty else { return true }

        return normalizedDriverLocation.contains(normalizedPickupLocation)
            || normalizedPickupLocation.contains(normalizedDriverLocation)
    }

    private func parseDatabaseDate(_ value: String?) -> Date? {
        guard let value else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func parseDatabaseTimestamp(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }

        // 1. Try ISO8601 with and without fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone(identifier: "UTC")
        
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: value) { return date }
        
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: value) { return date }

        // 2. Try DateFormatter with common Postgres and API formats
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        let formats = [
            "yyyy-MM-dd HH:mm:ss.SSSSSS", // Postgres default
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ssZZZZZ"
        ]

        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private func routeExperienceCount(
        for driverID: UUID,
        trips: [AssignmentTripRecord],
        routesById: [UUID: RouteRecord],
        normalizedOrigin: String,
        normalizedDestination: String
    ) -> Int {
        guard !normalizedOrigin.isEmpty, !normalizedDestination.isEmpty else { return 0 }

        let completedTrips = trips.filter { trip in
            guard trip.driver_id == driverID else { return false }
            guard let status = trip.status?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            return status == "completed" || status == "done"
        }

        return completedTrips.filter { trip in
            let tokens = routeTokens(from: trip, routesById: routesById)
            guard let tripOrigin = tokens.origin, let tripDestination = tokens.destination else { return false }

            let matchesForward = tripOrigin == normalizedOrigin && tripDestination == normalizedDestination
            let matchesBackward = tripOrigin == normalizedDestination && tripDestination == normalizedOrigin
            return matchesForward || matchesBackward
        }.count
    }

    private func routeTokens(from trip: AssignmentTripRecord, routesById: [UUID: RouteRecord]) -> (origin: String?, destination: String?) {
        if let routeId = trip.route_id, let route = routesById[routeId] {
            return (
                normalizeLocation(route.start_location),
                normalizeLocation(route.end_location)
            )
        }

        let origin = normalizeLocation(trip.origin ?? trip.start_location)
        let destination = normalizeLocation(trip.destination ?? trip.end_location)
        return (origin.isEmpty ? nil : origin, destination.isEmpty ? nil : destination)
    }

    private func normalizeLocation(_ value: String?) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return ""
        }

        let parts = value
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = parts.first else { return "" }
        let second = parts.count > 1 ? parts[1] : nil

        let firstLower = first.lowercased()
        let hasDigits = firstLower.rangeOfCharacter(from: .decimalDigits) != nil
        let roadTokens = ["road", "rd", "street", "st", "ave", "avenue", "highway", "hwy", "nh", "route", "bypass", "blvd", "lane", "ln"]
        let isRoadLike = roadTokens.contains { firstLower.contains($0) }

        let stateTokens: Set<String> = [
            "andhra pradesh", "arunachal pradesh", "assam", "bihar", "chhattisgarh", "goa", "gujarat",
            "haryana", "himachal pradesh", "jharkhand", "karnataka", "kerala", "madhya pradesh",
            "maharashtra", "manipur", "meghalaya", "mizoram", "nagaland", "odisha", "orissa", "punjab",
            "rajasthan", "sikkim", "tamil nadu", "telangana", "tripura", "uttar pradesh", "uttarakhand",
            "west bengal", "andaman and nicobar islands", "chandigarh", "dadra and nagar haveli",
            "daman and diu", "delhi", "jammu and kashmir", "ladakh", "lakshadweep", "puducherry",
            "mh", "ka", "tn", "ts", "ap", "up", "uk", "dl", "gj", "ga", "br", "wb", "od", "pb",
            "rj", "mp", "hp", "hr", "jh", "cg", "kl"
        ]

        func isState(_ value: String?) -> Bool {
            guard let value = value?.lowercased() else { return false }
            return stateTokens.contains(value)
        }

        let aliasMap: [String: String] = [
            "mysore": "mysuru",
            "mysuru": "mysuru",
            "bangalore": "bengaluru",
            "bengaluru": "bengaluru"
        ]

        if (hasDigits || isRoadLike), let second, !second.isEmpty {
            let candidate = second.lowercased()
            return aliasMap[candidate] ?? candidate
        }

        if let second, !second.isEmpty, !isState(second) {
            let candidate = second.lowercased()
            return aliasMap[candidate] ?? candidate
        }

        return aliasMap[firstLower] ?? firstLower
    }

    private func applyRouteRecommendation(to drivers: [DriverAssignmentOption]) -> [DriverAssignmentOption] {
        guard !drivers.isEmpty else { return drivers }
        let maxCount = drivers.map(\.routeExperienceCount).max() ?? 0
        let hasRecommendation = maxCount > 0

        let sorted = drivers.sorted { lhs, rhs in
            if lhs.routeExperienceCount != rhs.routeExperienceCount {
                return lhs.routeExperienceCount > rhs.routeExperienceCount
            }
            if lhs.locationHint != nil, rhs.locationHint == nil { return true }
            if lhs.locationHint == nil, rhs.locationHint != nil { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        guard hasRecommendation, let top = sorted.first else { return sorted }

        return sorted.map { driver in
            DriverAssignmentOption(
                id: driver.id,
                userID: driver.userID,
                name: driver.name,
                licenseNumber: driver.licenseNumber,
                licenseExpiry: driver.licenseExpiry,
                locationHint: driver.locationHint,
                routeExperienceCount: driver.routeExperienceCount,
                isRecommended: driver.id == top.id
            )
        }
    }

#if DEBUG
    private func debugLogRouteRecommendation(
        pickupLocation: String,
        destination: String,
        normalizedOrigin: String,
        normalizedDestination: String,
        trips: [AssignmentTripRecord],
        routesById: [UUID: RouteRecord],
        drivers: [DriverAssignmentOption]
    ) {
        print("🧭 Route recommendation debug")
        print("   Origin: \(pickupLocation) → \(destination)")
        print("   Normalized: \(normalizedOrigin) → \(normalizedDestination)")
        print("   Trips loaded: \(trips.count), routes loaded: \(routesById.count)")
        for trip in trips {
            let tokens = routeTokens(from: trip, routesById: routesById)
            let status = trip.status ?? "nil"
            let driver = trip.driver_id?.uuidString.prefix(6) ?? "nil"
            let routeId = trip.route_id?.uuidString.prefix(6) ?? "nil"
            print("   Trip \(trip.trip_id.uuidString.prefix(6)) status=\(status) driver=\(driver) route=\(routeId) tokens=\(tokens.origin ?? "-") → \(tokens.destination ?? "-")")
        }
        for driver in drivers {
            print("   Driver \(driver.name) (\(driver.id.uuidString.prefix(6))): routeCount=\(driver.routeExperienceCount), recommended=\(driver.isRecommended)")
        }
    }
#endif
}
