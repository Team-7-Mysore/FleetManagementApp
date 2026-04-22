import Foundation
import Combine
import Supabase
import UIKit

struct VehicleDocument: Identifiable, Hashable {
    let id: String
    let type: String
    var fileURL: String
    var fileName: String? = nil

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
        print("Opening vehicle detail id:", vehicleId.uuidString)

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
                    status,
                    vin,
                    registration_no,
                    registration_date,
                    rc_expiry_date,
                    puc_expiry_date
                """)
                .eq("vehicle_id", value: vehicleId.uuidString.lowercased())
                .single()
                .execute()

            print("Vehicle detail response:", String(data: response.data, encoding: .utf8) ?? "")
            self.vehicle = try Self.parseVehicle(from: response.data)

            do {
                let documentsData = try await fetchVehicleDocumentsData(vehicleId: vehicleId)
                print("Vehicle documents response:", String(data: documentsData, encoding: .utf8) ?? "")
                let fetchedDocuments = try Self.parseDocuments(from: documentsData)
                print("Vehicle documents count:", fetchedDocuments.count)
                self.documents = fetchedDocuments
                self.documentsErrorMessage = nil
            } catch {
                print("Error fetching vehicle documents:", error)
                self.documents = []
                self.documentsErrorMessage = error.localizedDescription
            }
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

    func uploadDocument(fileURL: URL, type: String) async {
        let originalName = fileURL.lastPathComponent
        do {
            let data = try Data(contentsOf: fileURL)
            let fileExtension = fileURL.pathExtension.isEmpty ? "pdf" : fileURL.pathExtension
            let uniqueName = "\(UUID().uuidString).\(fileExtension)"

            guard let url = URL(string: "\(SUPABASE_URL)/storage/v1/object/vehicle-documents/\(uniqueName)") else {
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

            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/vehicle-documents/\(uniqueName)"
            setDocumentURL(publicURL, for: type, fileName: originalName)
        } catch {
            print("Document upload failed for \(type):", error)
            errorMessage = error.localizedDescription
        }
    }

    func document(for type: String) -> VehicleDocument? {
        documents.first { $0.type.uppercased() == type.uppercased() }
    }

    func setDocumentURL(_ url: String, for type: String, fileName: String? = nil) {
        let normalizedType = type.uppercased()
        let resolvedFileName = fileName ?? URL(string: url)?.lastPathComponent
        
        if let index = documents.firstIndex(where: { $0.type.uppercased() == normalizedType }) {
            documents[index].fileURL = url
            documents[index].fileName = resolvedFileName
        } else {
            documents.append(VehicleDocument(
                id: normalizedType, 
                type: normalizedType, 
                fileURL: url,
                fileName: resolvedFileName
            ))
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
    func fetchVehicleDocumentsData(vehicleId: UUID) async throws -> Data {
        guard var components = URLComponents(string: "\(SUPABASE_URL)/rest/v1/vehicle_documents") else {
            throw URLError(.badURL)
        }

        components.queryItems = [
            URLQueryItem(name: "select", value: "document_id,document_type,file_url,file_name,uploaded_at"),
            URLQueryItem(name: "vehicle_id", value: "eq.\(vehicleId.uuidString.lowercased())")
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.addValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Failed to fetch vehicle documents"
            throw NSError(
                domain: "VehicleDetail",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        return data
    }

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

        var vehicle = Vehicle(
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
        vehicle.vin = stringValue(row["vin"]) ?? ""
        vehicle.rcNumber = stringValue(row["registration_no"]) ?? ""
        vehicle.registrationDate = stringValue(row["registration_date"]) ?? ""
        vehicle.rcExpiryDate = stringValue(row["rc_expiry_date"]) ?? ""
        vehicle.pucExpiryDate = stringValue(row["puc_expiry_date"]) ?? ""
        return vehicle
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
                fileURL: fileURL,
                fileName: row["file_name"] as? String ?? URL(string: fileURL)?.lastPathComponent
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
