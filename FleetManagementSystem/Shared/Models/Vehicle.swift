import Foundation

struct Vehicle: Identifiable, Codable {
    let id: UUID
    let name: String
    let registrationNumber: String
}
