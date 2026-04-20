import SwiftUI
import Combine
import Supabase

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

struct VehicleAssignmentOption: Identifiable, Decodable, Hashable {
    let vehicle_id: UUID
    let number_plate: String
    let vehicle_name: String?
    let vehicle_type: String?
    let status: String?

    var id: UUID { vehicle_id }

    var displayName: String {
        let trimmedName = vehicle_name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName?.isEmpty == false ? trimmedName! : number_plate
    }

    var subtitle: String {
        [vehicle_type, number_plate]
            .compactMap { value in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: " • ")
    }
}

struct DriverAssignmentOption: Identifiable, Hashable {
    let id: UUID
    let userID: UUID?
    let name: String
    let licenseNumber: String
    let licenseExpiry: String
    let locationHint: String?

    var subtitle: String {
        var components = ["License \(licenseNumber)"]
        if let locationHint, !locationHint.isEmpty {
            components.append(locationHint)
        }
        return components.joined(separator: " • ")
    }
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

private struct AssignmentTripRecord: Decodable {
    let trip_id: UUID
    let vehicle_id: UUID?
    let driver_id: UUID?
    let status: String?
    let start_time: String?
    let end_time: String?
    let pickup_time: String?
    let origin: String?
    let destination: String?
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

    func resetAssignmentOptions() {
        availableVehicles = []
        availableDrivers = []
        if !isLoadingAssignments {
            errorMessage = nil
        }
    }

    func loadAssignmentOptions(
        pickupLocation: String,
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
                    .select("trip_id, vehicle_id, driver_id, status, start_time, end_time, pickup_time, origin, destination, start_location, end_location")
                    .execute()
                    .value
            } catch {
                trips = []
            }

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

                availableDrivers = drivers
                    .filter { hasValidLicenseExpiry($0.license_expiry, relativeTo: pickupDate) }
                    .filter { !busyDriverIDs.contains($0.driver_id) }
                    .filter { isDriverNearPickup($0.driver_id, pickupLocation: trimmedPickupLocation, trips: trips) }
                    .map { driver in
                        let user = driver.user_id.flatMap { usersByID[$0] }
                        let inferredLocation = inferredDriverLocation(for: driver.driver_id, trips: trips)
                        return DriverAssignmentOption(
                            id: driver.driver_id,
                            userID: driver.user_id,
                            name: user?.name ?? "Driver \(driver.driver_id.uuidString.prefix(4))",
                            licenseNumber: driver.license_no,
                            licenseExpiry: driver.license_expiry,
                            locationHint: inferredLocation.map { "Near \($0)" }
                        )
                    }
                    .sorted { lhs, rhs in
                        if lhs.locationHint != nil, rhs.locationHint == nil { return true }
                        if lhs.locationHint == nil, rhs.locationHint != nil { return false }
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
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

    func createTrip(
        tripName: String,
        clientContact: String,
        origin: String,
        destination: String,
        viaPoints: [String],
        pickupDate: Date,
        expectedEndDate: Date,
        vehicleID: UUID?,
        driverID: UUID?
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

        let formatter = ISO8601DateFormatter()
        let pickupISODate = formatter.string(from: pickupDate)
        let endISODate = formatter.string(from: expectedEndDate)

        let trip = TripInsert(
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
            status: "assigned"
        )

        print("📍 Creating trip with locations:")
        print("   Origin: \(origin)")
        print("   Destination: \(destination)")
        print("   Via Points: \(viaPoints)")

        do {
            try await SupabaseManager.shared.client
                .from("trips")
                .insert(trip)
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
        return ["assigned", "scheduled", "pending", "in_progress", "in progress", "in_transit", "in transit"].contains(status)
    }

    private func overlaps(
        existingStart: Date?,
        existingEnd: Date?,
        requestedStart: Date,
        requestedEnd: Date
    ) -> Bool {
        guard let existingStart else { return false }
        let computedExistingEnd = existingEnd ?? Calendar.current.date(byAdding: .hour, value: 4, to: existingStart) ?? existingStart
        return existingStart < requestedEnd && computedExistingEnd > requestedStart
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

    private func normalizeLocation(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func parseDatabaseDate(_ value: String?) -> Date? {
        guard let value else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func parseDatabaseTimestamp(_ value: String?) -> Date? {
        guard let value else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }
}
