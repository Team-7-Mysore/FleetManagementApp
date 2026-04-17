import Foundation

struct Vehicle: Identifiable, Codable {
    let id: UUID
    let name: String
    let registrationNumber: String
    let brand: String?
    let model: String?
    let imageURL: String?
    
    enum CodingKeys: String, CodingKey {
          case id = "vehicle_id"
          case name = "vehicle_name"
          case registrationNumber = "number_plate" 
          case brand
          case model
        case imageURL = "image_url"
      }
}
