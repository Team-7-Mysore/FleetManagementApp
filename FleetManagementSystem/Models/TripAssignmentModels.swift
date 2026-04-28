import Foundation

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

struct AssignmentTripRecord: Decodable {
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
