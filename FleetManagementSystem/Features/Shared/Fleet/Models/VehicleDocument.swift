import Foundation

enum DocumentType: String, Codable, CaseIterable {
    case insurance = "Insurance"
    case registration = "Registration"
    case driverLicense = "Driver License"
    case fitness = "Fitness Certificate"
    case permit = "Permit"
    
    var icon: String {
        switch self {
        case .insurance: return "shield.checkered"
        case .registration: return "doc.text.fill"
        case .driverLicense: return "person.text.rectangle.fill"
        case .fitness: return "checkmark.seal.fill"
        case .permit: return "map.fill"
        }
    }
}

struct VehicleDocument: Identifiable, Codable {
    let id: UUID
    let vehicleId: UUID?
    let driverId: UUID?
    let type: DocumentType
    let documentNumber: String?
    let issueDate: Date?
    let expiryDate: Date
    let fileUrl: String?
    let createdAt: Date
    
    var isExpiringSoon: Bool {
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        return expiryDate <= thirtyDaysFromNow && expiryDate > Date()
    }
    
    var isExpired: Bool {
        return expiryDate < Date()
    }
    
    var daysToExpiry: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExpiry = calendar.startOfDay(for: expiryDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiry)
        return components.day ?? 0
    }
}
