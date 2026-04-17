import Foundation
import Combine
import Supabase

struct VehicleDocument: Identifiable, Hashable {
    let id: String
    let type: String
    let fileURL: String

    var title: String {
        switch type.uppercased() {
        case "RC":
            return "RC"
        case "INSURANCE":
            return "Insurance"
        case "PUC":
            return "PUC"
        default:
            return type.capitalized
        }
    }

    var statusText: String {
        switch type.uppercased() {
        case "RC":
            return "Valid"
        case "INSURANCE":
            return "Expiring Soon"
        case "PUC":
            return "Expired"
        default:
            return "Available"
        }
    }
}

private struct VehicleDocumentRecord: Decodable {
    let document_type: String?
    let file_url: String?
}

class VehicleDetailViewModel: ObservableObject {
    
    @Published var vehicle: Vehicle?
    @Published var documents: [VehicleDocument] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchVehicle(vehicleId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            async let vehicleResponse = SupabaseManager.shared.client
                .from("vehicles")
                .select()
                .eq("vehicle_id", value: vehicleId)
                .single()
                .execute()

            async let documentResponse = SupabaseManager.shared.client
                .from("vehicle_documents")
                .select("document_type, file_url")
                .eq("vehicle_id", value: vehicleId)
                .execute()

            let vehicleData = try await vehicleResponse.data
            self.vehicle = try Self.parseVehicle(from: vehicleData)

            do {
                let documentData = try await documentResponse.data
                self.documents = try Self.parseDocuments(from: documentData)
            } catch {
                print("Error fetching vehicle documents:", error)
                self.documents = []
            }

        } catch {
            print("Error fetching vehicle:", error)
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateVehicle() async -> Bool {
        guard let vehicle = vehicle else { return false }

        do {
            errorMessage = nil
            _ = try await SupabaseManager.shared.client
                .from("vehicles")
                .update(vehicle)
                .eq("vehicle_id", value: vehicle.id)
                .execute()
            return true
        } catch {
            print("Update failed:", error)
            errorMessage = error.localizedDescription
            return false
        }
    }
}

private extension VehicleDetailViewModel {
    static func parseVehicle(from data: Data) throws -> Vehicle {
        guard let row = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "VehicleDetail",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Vehicle response was not a JSON object."]
            )
        }

        guard let idString = stringValue(row["vehicle_id"]),
              let id = UUID(uuidString: idString) else {
            throw NSError(
                domain: "VehicleDetail",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Vehicle record is missing a valid id."]
            )
        }

        let plate = stringValue(row["number_plate"])
        let name = stringValue(row["vehicle_name"])
        let type = stringValue(row["vehicle_type"])

        return Vehicle(
            id: id,
            name: preferredText(name, fallback: plate, defaultValue: "Unnamed Vehicle"),
            registrationNumber: preferredText(plate, fallback: nil, defaultValue: "No Plate"),
            brand: stringValue(row["brand"]),
            model: stringValue(row["model"]),
            imageURL: stringValue(row["image_url"]),
            vehicleType: preferredText(type, fallback: nil, defaultValue: "Unknown"),
            fuelType: stringValue(row["fuel_type"]),
            modelYear: stringValue(row["model_year"])
        )
    }

    static func parseDocuments(from data: Data) throws -> [VehicleDocument] {
        let rows = try JSONDecoder().decode([VehicleDocumentRecord].self, from: data)

        return rows.compactMap { row in
            guard let type = row.document_type?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !type.isEmpty,
                  let fileURL = row.file_url?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !fileURL.isEmpty else {
                return nil
            }

            return VehicleDocument(
                id: "\(type)-\(fileURL)",
                type: type,
                fileURL: fileURL
            )
        }
    }

    static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case is NSNull, nil:
            return nil
        default:
            return String(describing: value!)
        }
    }

    static func preferredText(_ primary: String?, fallback: String?, defaultValue: String) -> String {
        let primaryTrimmed = primary?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let primaryTrimmed, !primaryTrimmed.isEmpty {
            return primaryTrimmed
        }

        let fallbackTrimmed = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fallbackTrimmed, !fallbackTrimmed.isEmpty {
            return fallbackTrimmed
        }

        return defaultValue
    }
}
