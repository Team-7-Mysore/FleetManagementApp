import Foundation
import SwiftUI

struct Vehicle: Identifiable, Codable {
    var id: UUID
    var name: String
    var registrationNumber: String
    var createdAt: Date?
    var brand: String?
    var model: String?
    var imageURL: String?
    var vehicleType: String
    var fuelType: String?
    var modelYear: String?
    var status: String?

    // Required fields
    var vin: String = ""
    var rcNumber: String = ""
    var registrationDate: String = ""
    var rcExpiryDate: String = ""
    var pucExpiryDate: String = ""

    enum CodingKeys: String, CodingKey {
        case id = "vehicle_id"
        case name = "vehicle_name"
        case registrationNumber = "number_plate"
        case brand, model, status
        case imageURL = "image_url"
        case createdAt = "created_at"
        case vehicleType = "vehicle_type"
        case fuelType = "fuel_type"
        case modelYear = "model_year"
        case vin
        case rcNumber = "registration_no"
        case registrationDate = "registration_date"
        case rcExpiryDate = "rc_expiry_date"
        case pucExpiryDate = "puc_expiry_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        registrationNumber = try container.decode(String.self, forKey: .registrationNumber)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        vehicleType = (try container.decodeIfPresent(String.self, forKey: .vehicleType)) ?? "Unknown"
        fuelType = try container.decodeIfPresent(String.self, forKey: .fuelType)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        vin = try container.decodeIfPresent(String.self, forKey: .vin) ?? ""
        rcNumber = try container.decodeIfPresent(String.self, forKey: .rcNumber) ?? ""
        registrationDate = try container.decodeIfPresent(String.self, forKey: .registrationDate) ?? ""
        rcExpiryDate = try container.decodeIfPresent(String.self, forKey: .rcExpiryDate) ?? ""
        pucExpiryDate = try container.decodeIfPresent(String.self, forKey: .pucExpiryDate) ?? ""

        if let stringYear = try? container.decodeIfPresent(String.self, forKey: .modelYear) {
            modelYear = stringYear
        } else if let intYear = try? container.decodeIfPresent(Int.self, forKey: .modelYear) {
            modelYear = String(intYear)
        } else {
            modelYear = nil
        }
    }

    init(
        id: UUID,
        name: String,
        registrationNumber: String,
        brand: String? = nil,
        model: String? = nil,
        imageURL: String? = nil,
        vehicleType: String,
        fuelType: String? = nil,
        modelYear: String? = nil
    ) {
        self.id = id
        self.name = name
        self.registrationNumber = registrationNumber
        self.brand = brand
        self.model = model
        self.imageURL = imageURL
        self.vehicleType = vehicleType
        self.fuelType = fuelType
        self.modelYear = modelYear
    }

    init(dto: VehicleDTO) {
        self.id = UUID(uuidString: dto.vehicleId) ?? UUID()
        self.name = dto.vehicleName ?? dto.numberPlate ?? "Unnamed Vehicle"
        self.registrationNumber = dto.numberPlate ?? "No Plate"
        self.brand = dto.brand
        self.model = dto.model
        self.imageURL = nil
        self.vehicleType = dto.vehicleType ?? "Unknown"
        self.fuelType = dto.fuelType
        self.modelYear = dto.modelYear.map { String($0) }
    }

    var make: String { brand ?? "Unknown" }
    var licensePlate: String { registrationNumber }
    var year: Int { Int(modelYear ?? "") ?? 0 }
    var fuelPercentage: Int { 75 }
    var formattedMileage: String { "N/A" }

    // MARK: - In Vehicle.swift

    var statusColor: Color {
        switch status?.lowercased() {
        case "active":
            return .blue // Matches your screenshot
        case "under_maintenance", "maintenance":
            return .orange
        case "inactive":
            return .gray
        case "out_of_service":
            return .red
        default:
            return .blue // Fallback to blue/active if null
        }
    }

    var statusDisplayName: String {
        guard let status = status else { return "Active" }
        switch status.lowercased() {
        case "active":
            return "Active"
        case "under_maintenance", "maintenance":
            return "Maintenance"
        case "inactive":
            return "Inactive"
        default:
            // Handles other statuses and turns "on_trip" into "On Trip"
            return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var imageSystemName: String {
        let type = vehicleType.lowercased()
        if type.contains("bike") || type.contains("motor") {
            return "motorcycle.fill"
        } else if type.contains("car") || type.contains("sedan") || type.contains("suv") {
            return "car.side.fill"
        } else {
            return "truck.box.fill"
        }
    }
}
