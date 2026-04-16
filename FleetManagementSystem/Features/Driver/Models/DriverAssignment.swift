import Foundation

struct DriverAssignment: Codable, Equatable {
    let vehicleName: String
    let registrationNumber: String
    let routeName: String
    let shiftWindow: String
    let startLocation: String
    let destination: String
    let scheduledStart: String
    let cargoSummary: String
}
