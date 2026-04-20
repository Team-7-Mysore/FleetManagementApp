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
        vehicleType = try container.decode(String.self, forKey: .vehicleType)
        fuelType = try container.decodeIfPresent(String.self, forKey: .fuelType)

        if let stringYear = try container.decodeIfPresent(String.self, forKey: .modelYear) {
            modelYear = stringYear
        } else if let intYear = try container.decodeIfPresent(Int.self, forKey: .modelYear) {
            modelYear = String(intYear)
        } else {
            modelYear = nil
        }
    }

    init(
        id: UUID,
        name: String,
        registrationNumber: String,
        brand: String?,
        model: String?,
        imageURL: String?,
        vehicleType: String,
        fuelType: String?,
        modelYear: String?
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
}
