import Foundation
import Combine
import Supabase
import UIKit

struct VehicleDocument: Identifiable, Hashable {
    let id: String
    let type: String
    var fileURL: String

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

private struct VehicleUpdatePayload: Encodable {
    let vehicle_name: String
    let number_plate: String
    let brand: String?
    let model: String?
    let image_url: String?
    let vehicle_type: String
    let fuel_type: String?
    let model_year: String?
}

@MainActor
class VehicleDetailViewModel: ObservableObject {

    @Published var vehicle: Vehicle?
    @Published var documents: [VehicleDocument] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var documentsErrorMessage: String?

    func fetchVehicle(vehicleId: UUID) async {
        isLoading = true
        errorMessage = nil
        documentsErrorMessage = nil

        do {
            let response = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("""
                    vehicle_id,
                    vehicle_name,
                    number_plate,
                    brand,
                    model,
                    image_url,
                    vehicle_type,
                    fuel_type,
                    model_year,
                    vehicle_documents(document_id, document_type, file_url, file_name, uploaded_at)
                """)
                .eq("vehicle_id", value: vehicleId)
                .single()
                .execute()

            print("Vehicle detail response:", String(data: response.data, encoding: .utf8) ?? "")
            let detail = try Self.parseVehicleDetail(from: response.data)
            print("Vehicle documents count:", detail.documents.count)
            self.vehicle = detail.vehicle
            self.documents = detail.documents
        } catch {
            print("Error fetching vehicle:", error)
            errorMessage = error.localizedDescription
            documents = []
        }

        isLoading = false
    }

    func updateVehicle() async -> Bool {
        guard let vehicle else { return false }

        do {
            errorMessage = nil
            let payload = VehicleUpdatePayload(
                vehicle_name: vehicle.name,
                number_plate: vehicle.registrationNumber,
                brand: vehicle.brand,
                model: vehicle.model,
                image_url: vehicle.imageURL,
                vehicle_type: vehicle.vehicleType,
                fuel_type: vehicle.fuelType,
                model_year: vehicle.modelYear
            )

            try await SupabaseManager.shared.client
                .from("vehicles")
                .update(payload)
                .eq("vehicle_id", value: vehicle.id)
                .execute()

            try await syncDocuments(for: vehicle.id)
            return true
        } catch {
            print("Update failed:", error)
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - IMAGE UPLOAD
    func uploadImage(image: UIImage, type: String = "VEHICLE") async {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }

        let fileName = UUID().uuidString + ".jpg"
        let bucket = type == "VEHICLE" ? "vehicle-images" : "vehicle-documents"

        let url = URL(string: "\(SUPABASE_URL)/storage/v1/object/\(bucket)/\(fileName)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        do {
            let (_, res) = try await URLSession.shared.upload(for: request, from: data)

            guard (res as? HTTPURLResponse)?.statusCode == 200 else { return }

            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/\(bucket)/\(fileName)"

            if type == "VEHICLE" {
                self.vehicle?.imageURL = publicURL
            } else {
                setDocumentURL(publicURL, for: type)
            }

        } catch {
            print("Upload error:", error)
        }
    }

    func setDocumentURL(_ url: String, for type: String) {
        let normalizedType = type.uppercased()
        if let index = documents.firstIndex(where: { $0.type.uppercased() == normalizedType }) {
            documents[index].fileURL = url
        } else {
            documents.append(VehicleDocument(id: normalizedType, type: normalizedType, fileURL: url))
        }
        documents = Self.sortDocuments(documents)
    }

    func syncDocuments(for vehicleID: UUID) async throws {
        try await SupabaseManager.shared.client
            .from("vehicle_documents")
            .delete()
            .eq("vehicle_id", value: vehicleID)
            .execute()

        let records = documents
            .filter { !$0.fileURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map {
            [
                "vehicle_id": vehicleID.uuidString,
                "document_type": $0.type,
                "file_url": $0.fileURL
            ]
        }

        guard !records.isEmpty else { return }

        try await SupabaseManager.shared.client
            .from("vehicle_documents")
            .insert(records)
            .execute()
    }
}

private extension VehicleDetailViewModel {
    static func parseVehicleDetail(from data: Data) throws -> (vehicle: Vehicle, documents: [VehicleDocument]) {
        guard let row = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "VehicleDetail",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Vehicle response was not a JSON object."]
            )
        }

        let vehicleData = try JSONSerialization.data(withJSONObject: row)
        let vehicle = try parseVehicle(from: vehicleData)

        let nestedDocuments = row["vehicle_documents"] ?? []
        let documentData = try JSONSerialization.data(withJSONObject: nestedDocuments)
        let documents = try parseDocuments(from: documentData)
        return (vehicle, documents)
    }

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
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let parsed: [VehicleDocument] = rows.compactMap { row in
            guard let type = stringValue(row["document_type"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !type.isEmpty,
                  let fileURL = stringValue(row["file_url"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !fileURL.isEmpty else {
                return nil
            }

            return VehicleDocument(
                id: type.uppercased(),
                type: type.uppercased(),
                fileURL: fileURL
            )
        }

        return sortDocuments(parsed)
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

    static func sortDocuments(_ documents: [VehicleDocument]) -> [VehicleDocument] {
        let ordering = ["RC": 0, "INSURANCE": 1, "PUC": 2]
        return documents.sorted { lhs, rhs in
            let lhsOrder = ordering[lhs.type.uppercased()] ?? 99
            let rhsOrder = ordering[rhs.type.uppercased()] ?? 99
            if lhsOrder == rhsOrder {
                return lhs.title < rhs.title
            }
            return lhsOrder < rhsOrder
        }
    }
}
