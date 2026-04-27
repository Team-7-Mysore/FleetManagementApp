import Foundation

struct DriverReportDTO: Codable {
    var id: UUID?
    let driverId: UUID
    let vehicleId: UUID
    var tripId: UUID?
    let category: String
    let severity: String
    let description: String
    var status: String = "reported"
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case category
        case severity
        case description
        case status
        case createdAt = "created_at"
    }
}
