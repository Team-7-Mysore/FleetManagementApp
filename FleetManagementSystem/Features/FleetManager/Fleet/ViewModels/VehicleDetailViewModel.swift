import Foundation
import Combine
import Supabase
import UIKit

// MARK: - Model
struct VehicleDocument: Identifiable, Hashable {
    let id: String
    let type: String
    var fileURL: String

    var title: String {
        switch type {
        case "RC": return "RC"
        case "INSURANCE": return "Insurance"
        case "PUC": return "PUC"
        default: return type
        }
    }
}

// MARK: - Update Payload (FIX FOR ENCODABLE ERROR)
struct VehicleUpdatePayload: Encodable {
    let vehicle_name: String
    let number_plate: String
    let brand: String?
    let model: String?
    let image_url: String?
    let vehicle_type: String
    let fuel_type: String?
    let model_year: String?
}

// MARK: - ViewModel
@MainActor
class VehicleDetailViewModel: ObservableObject {

    @Published var vehicle: Vehicle?
    @Published var documents: [VehicleDocument] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - FETCH VEHICLE
    func fetchVehicle(vehicleId: UUID) async {
        isLoading = true
        errorMessage = nil
        documents = []

        do {
            let response = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("*")
                .eq("vehicle_id", value: vehicleId.uuidString.lowercased())
                .single()
                .execute()

            self.vehicle = try Self.parseVehicle(from: response.data)
            await fetchDocuments(vehicleId: vehicleId)

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - FETCH DOCUMENTS
    private func fetchDocuments(vehicleId: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("vehicle_documents")
                .select("*")
                .eq("vehicle_id", value: vehicleId.uuidString.lowercased())
                .execute()

            self.documents = try Self.parseDocuments(from: response.data)

        } catch {
            print("❌ Document fetch error:", error)
            self.documents = []
        }
    }

    // MARK: - UPDATE VEHICLE (FIXED)
    func updateVehicle() async -> Bool {
        guard let vehicle else { return false }

        do {
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
                .eq("vehicle_id", value: vehicle.id.uuidString.lowercased())
                .execute()

            try await syncDocuments(for: vehicle.id)

            return true

        } catch {
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

    // MARK: - 🔥 FIXED MISSING FUNCTION
    func setDocumentURL(_ url: String, for type: String) {
        if let index = documents.firstIndex(where: { $0.type == type }) {
            documents[index].fileURL = url
        } else {
            documents.append(VehicleDocument(id: type, type: type, fileURL: url))
        }
    }

    // MARK: - SYNC DOCUMENTS
    func syncDocuments(for vehicleID: UUID) async throws {
        try await SupabaseManager.shared.client
            .from("vehicle_documents")
            .delete()
            .eq("vehicle_id", value: vehicleID.uuidString.lowercased())
            .execute()

        let records = documents.map {
            [
                "vehicle_id": vehicleID.uuidString.lowercased(),
                "document_type": $0.type,
                "file_url": $0.fileURL
            ]
        }

        try await SupabaseManager.shared.client
            .from("vehicle_documents")
            .insert(records)
            .execute()
    }
}

// MARK: - Parsing
private extension VehicleDetailViewModel {

    static func parseVehicle(from data: Data) throws -> Vehicle {
        let row = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        return Vehicle(
            id: UUID(uuidString: row["vehicle_id"] as! String)!,
            name: row["vehicle_name"] as? String ?? "",
            registrationNumber: row["number_plate"] as? String ?? "",
            brand: row["brand"] as? String,
            model: row["model"] as? String,
            imageURL: row["image_url"] as? String,
            vehicleType: row["vehicle_type"] as? String ?? "",
            fuelType: row["fuel_type"] as? String,
            modelYear: (row["model_year"] as? NSNumber)?.stringValue
        )
    }

    static func parseDocuments(from data: Data) throws -> [VehicleDocument] {
        let rows = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]

        return rows.compactMap {
            guard let type = $0["document_type"] as? String,
                  let url = $0["file_url"] as? String else { return nil }

            return VehicleDocument(id: type, type: type, fileURL: url)
        }
    }
}
