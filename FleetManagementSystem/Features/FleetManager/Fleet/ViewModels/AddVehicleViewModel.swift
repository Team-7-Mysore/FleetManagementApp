import SwiftUI
import Combine
import UIKit
import Supabase

class AddVehicleViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSuccess = false
    
    // MARK: - Form Fields
    @Published var vehicleName = ""
    @Published var licensePlate = ""
    @Published var vin = ""
    @Published var rcNumber = ""
    @Published var brand = ""
    @Published var manufacturer = ""
    @Published var model = ""
    @Published var modelYear = ""
    @Published var vehicleType = "Truck"
    @Published var fuelType = "Diesel"
    
    // MARK: - Dates
    @Published var registrationDate = Date()
    @Published var pucExpiry = Date()
    @Published var rcExpiry = Date()
    
    // Asset URLs
    @Published var vehicleImageURL: String?
    @Published var rcURL: String?
    @Published var insuranceURL: String?
    @Published var pucURL: String?
    
    @Published var localVehicleImage: UIImage?
    @Published var rcFileName: String?
    @Published var insuranceFileName: String?
    @Published var pucFileName: String?

    // MARK: - Validation Checkers
    
    var isPlateValidCheck: Bool {
        isValidPlate(licensePlate)
    }

    var isFormValid: Bool {
        let isNameValid = !vehicleName.trimmingCharacters(in: .whitespaces).isEmpty
        let isVinValid = vin.count == 17
        let isPlateValid = isPlateValidCheck
        let isRCValid = !rcNumber.isEmpty
        let documentsValid = rcURL != nil
        
        return isNameValid && isVinValid && isPlateValid && isRCValid && documentsValid && !isLoading
    }

    // MARK: - Formatting Helpers

    func formatPlate(_ input: String) -> String {
        let raw = input.uppercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
        let normalized = String(raw.prefix(10))
        
        var result = ""
        for (index, char) in normalized.enumerated() {
            if index == 2 || index == 4 || index == 6 {
                result.append("-")
            }
            result.append(char)
        }
        return result
    }

    private func isValidPlate(_ input: String) -> Bool {
        // Pattern: AA-00-AA-0000
        let regex = "^[A-Z]{2}-[0-9]{2}-[A-Z]{1,2}-[0-9]{4}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: input)
    }

    private func isValidRC(_ input: String) -> Bool {
        let rcRegex = "^[A-Z0-9/]{8,20}$"
        return NSPredicate(format: "SELF MATCHES %@", rcRegex).evaluate(with: input.uppercased())
    }
    
    // MARK: - Persistence (Save to Supabase)
    
    func saveVehicle() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        let sqlDateFormatter = DateFormatter()
        sqlDateFormatter.dateFormat = "yyyy-MM-dd"

        let payload: [String: Any] = [
            "image_url": vehicleImageURL ?? "",
            "vehicleName": vehicleName.trimmingCharacters(in: .whitespaces),
            "registrationNumber": licensePlate,
            "vin": vin.uppercased().trimmingCharacters(in: .whitespaces),
            "rc_number": rcNumber.uppercased().trimmingCharacters(in: .whitespaces),
            "brand": brand,
            "manufacturer": manufacturer,
            "model": model,
            "model_year": Int(modelYear) ?? 0,
            "vehicleType": vehicleType,
            "fuelType": fuelType,
            "registrationDate": sqlDateFormatter.string(from: registrationDate),
            "pucExpiry": sqlDateFormatter.string(from: pucExpiry),
            "rcExpiry": sqlDateFormatter.string(from: rcExpiry),
            "documents": [
                rcURL != nil ? ["type": "RC", "url": rcURL!, "name": rcFileName ?? "RC_Doc"] : nil,
                insuranceURL != nil ? ["type": "INSURANCE", "url": insuranceURL!, "name": insuranceFileName ?? "Insurance_Doc"] : nil,
                pucURL != nil ? ["type": "PUC", "url": pucURL!, "name": pucFileName ?? "PUC_Doc"] : nil
            ].compactMap { $0 }
        ]

        do {
            let functionURL = URL(string: "\(SUPABASE_URL)/functions/v1/bright-action")!
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                await MainActor.run { self.isSuccess = true }
            } else {
                throw NSError(domain: "SupabaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to save vehicle"])
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        await MainActor.run { self.isLoading = false }
    }
    
    // MARK: - Upload Methods
    func uploadImage(image: UIImage, type: String) async {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let fileName = "\(UUID().uuidString).jpg"
        let bucket = (type == "VEHICLE") ? "vehicle-images" : "vehicle-documents"
        do {
            let storage = SupabaseManager.shared.client.storage.from(bucket)
            try await storage.upload(path: fileName, file: data, options: FileOptions(contentType: "image/jpeg"))
            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/\(bucket)/\(fileName)"
            await MainActor.run {
                if type == "VEHICLE" { self.vehicleImageURL = publicURL }
                else if type == "RC" { self.rcURL = publicURL; self.rcFileName = "Photo_RC.jpg" }
            }
        } catch { print("Upload failed") }
    }

    func uploadFile(fileURL: URL, type: String) async {
        do {
            let data = try Data(contentsOf: fileURL)
            let fileName = "\(UUID().uuidString).\(fileURL.pathExtension)"
            let storage = SupabaseManager.shared.client.storage.from("vehicle-documents")
            try await storage.upload(path: fileName, file: data)
            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/vehicle-documents/\(fileName)"
            await MainActor.run {
                if type == "RC" { self.rcURL = publicURL; self.rcFileName = fileURL.lastPathComponent }
            }
        } catch { print("File failed") }
    }
}
