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

private struct VehicleDocumentRecord: Decodable {
    let document_id: UUID?
    let document_type: String?
    let file_url: String?
    let file_name: String?
    let uploaded_at: String?
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

            let detail = try Self.parseVehicleDetail(from: response.data)
            self.vehicle = detail.vehicle
            self.documents = detail.documents
            if detail.documents.isEmpty {
                self.documentsErrorMessage = nil
            }
        } catch {
            print("Error fetching vehicle:", error)
            errorMessage = error.localizedDescription
            documents = []
        }

        isLoading = false
    }

    func updateVehicle() async -> Bool {
        guard let vehicle = vehicle else { return false }

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
            _ = try await SupabaseManager.shared.client
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

    func uploadImage(image: UIImage, type: String = "VEHICLE") async {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }

        do {
            let bucketName = type == "VEHICLE" ? "vehicle-images" : "vehicle-documents"
            let publicURL = try await uploadData(
                data,
                fileExtension: "jpg",
                bucketName: bucketName
            )

            if type == "VEHICLE" {
                vehicle?.imageURL = publicURL
            } else {
                setDocumentURL(publicURL, for: type)
            }
        } catch {
            print("Upload failed for \(type):", error)
            errorMessage = error.localizedDescription
        }
    }

    func uploadDocument(fileURL: URL, type: String) async {
        do {
            let data = try Data(contentsOf: fileURL)
            let fileExtension = fileURL.pathExtension.isEmpty ? "pdf" : fileURL.pathExtension
            let publicURL = try await uploadData(
                data,
                fileExtension: fileExtension,
                bucketName: "vehicle-documents"
            )
            setDocumentURL(publicURL, for: type)
        } catch {
            print("Document upload failed for \(type):", error)
            errorMessage = error.localizedDescription
        }
    }

    func document(for type: String) -> VehicleDocument? {
        documents.first { $0.type.uppercased() == type.uppercased() }
    }

    func setDocumentURL(_ fileURL: String, for type: String) {
        let normalizedType = type.uppercased()
        if let index = documents.firstIndex(where: { $0.type.uppercased() == normalizedType }) {
            documents[index].fileURL = fileURL
        } else {
            documents.append(
                VehicleDocument(
                    id: normalizedType,
                    type: normalizedType,
                    fileURL: fileURL
                )
            )
        }
        documents = Self.sortDocuments(documents)
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

    func syncDocuments(for vehicleID: UUID) async throws {
        let payload = documents
            .filter { !$0.fileURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { document in
            [
                "vehicle_id": vehicleID.uuidString,
                "document_type": document.type,
                "file_url": document.fileURL
            ]
        }

        guard let baseURL = URL(string: "\(SUPABASE_URL)/rest/v1/vehicle_documents") else {
            throw URLError(.badURL)
        }

        guard var deleteComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        deleteComponents.queryItems = [
            URLQueryItem(name: "vehicle_id", value: "eq.\(vehicleID.uuidString)")
        ]

        guard let deleteURL = deleteComponents.url else {
            throw URLError(.badURL)
        }

        var deleteRequest = URLRequest(url: deleteURL)
        deleteRequest.httpMethod = "DELETE"
        deleteRequest.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        deleteRequest.addValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        deleteRequest.addValue("return=minimal", forHTTPHeaderField: "Prefer")

        let (deleteData, deleteResponse) = try await URLSession.shared.data(for: deleteRequest)
        guard let deleteHTTPResponse = deleteResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= deleteHTTPResponse.statusCode else {
            let message = String(data: deleteData, encoding: .utf8) ?? "Failed to remove existing documents"
            throw NSError(
                domain: "VehicleDetail",
                code: deleteHTTPResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        guard !payload.isEmpty else { return }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.addValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Failed to sync documents"
            throw NSError(
                domain: "VehicleDetail",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    func uploadData(_ data: Data, fileExtension: String, bucketName: String) async throws -> String {
        let safeExtension = fileExtension.isEmpty ? "bin" : fileExtension
        let fileName = "\(UUID().uuidString).\(safeExtension)"
        guard let url = URL(string: "\(SUPABASE_URL)/storage/v1/object/\(bucketName)/\(fileName)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return "\(SUPABASE_URL)/storage/v1/object/public/\(bucketName)/\(fileName)"
    }
}
