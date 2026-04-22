import Foundation

struct Vehicle: Identifiable, Codable {
    var id: UUID
    var name: String
    var registrationNumber: String
    var brand: String?
    var model: String?
    var imageURL: String?
    var vehicleType: String
    var fuelType: String?
    var modelYear: String?

    // Additional display properties (computed from existing fields)
    var make: String { brand ?? "Unknown" }
    var licensePlate: String { registrationNumber }
    var year: Int { Int(modelYear ?? "") ?? 0 }
    var fuelPercentage: Int { 75 } // Placeholder - extend DB if needed
    var formattedMileage: String { "N/A" } // Placeholder - extend DB if needed

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

    enum CodingKeys: String, CodingKey {
        case id = "vehicle_id"
        case name = "vehicle_name"
        case registrationNumber = "number_plate"
        case brand
        case model
        case imageURL = "image_url"
        case vehicleType = "vehicle_type"
        case fuelType = "fuel_type"
        case modelYear = "model_year"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        registrationNumber = try container.decode(String.self, forKey: .registrationNumber)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        vehicleType = (try container.decodeIfPresent(String.self, forKey: .vehicleType)) ?? "Unknown"
        fuelType = try container.decodeIfPresent(String.self, forKey: .fuelType)

        // Handle model_year which can be either Int or String in the database
        if let intYear = try? container.decodeIfPresent(Int.self, forKey: .modelYear) {
            modelYear = String(intYear)
        } else if let stringYear = try? container.decodeIfPresent(String.self, forKey: .modelYear) {
            modelYear = stringYear
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

    // MARK: - Init from VehicleDTO
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
}
