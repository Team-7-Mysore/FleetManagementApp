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
    
    // MARK: - Asset URLs (Supabase Storage)
    @Published var vehicleImageURL: String?
    @Published var rcURL: String?
    @Published var insuranceURL: String?
    @Published var pucURL: String?
    
    // MARK: - Local UI State (Files/Images)
    @Published var localVehicleImage: UIImage?
    @Published var rcFileName: String?
    @Published var insuranceFileName: String?
    @Published var pucFileName: String?

    // MARK: - Validation Logic
    
    var isFormValid: Bool {
            let isNameValid = !vehicleName.trimmingCharacters(in: .whitespaces).isEmpty
            let isVinValid = vin.count == 17
            let isPlateValid = isValidPlate(licensePlate)
            let isRCValid = !rcNumber.isEmpty
            let documentsValid = rcURL != nil && insuranceURL != nil
            
            return isNameValid && isVinValid && isPlateValid && isRCValid && documentsValid && !isLoading
        }
    
    func validate() -> String? {
        if vehicleName.trimmingCharacters(in: .whitespaces).isEmpty { return "Vehicle Name is required." }
        if !isValidPlate(licensePlate) { return "Invalid License Plate. Use format: XX-00-XX-0000" }
        if vin.count != 17 { return "VIN must be exactly 17 characters." }
        if !isValidRC(rcNumber) { return "Invalid RC Number (8-20 alphanumeric characters)." }
        
        // Document requirements
        if rcURL == nil { return "RC Document upload is compulsory." }
        if insuranceURL == nil { return "Insurance Policy upload is compulsory." }
        
        // Date Logic
        if registrationDate > Date() { return "Registration date cannot be in the future." }
        
        return nil
    }

    // MARK: - Formatting Helpers
    
    func formatPlate(_ input: String) -> String {
            let normalized = input.uppercased().replacingOccurrences(of: "[^A-Z0-9]", with: "", options: .regularExpression)
            var result = ""
            for (index, char) in normalized.enumerated() {
                // Logic for XX-00-XX-0000
                if index == 2 || index == 4 || index == 6 { result.append("-") }
                if result.count < 13 { // Max length for XX-00-XX-0000
                    result.append(char)
                }
            }
            return result
        }
    private func isValidPlate(_ input: String) -> Bool {
            let regex = "^[A-Z]{2}-[0-9]{2}-[A-Z]{1,2}-[0-9]{4}$"
            return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: input)
        }

    private func isValidRC(_ input: String) -> Bool {
        let rcRegex = "^[A-Z0-9/]{8,20}$"
        return NSPredicate(format: "SELF MATCHES %@", rcRegex).evaluate(with: input.uppercased())
    }

    // MARK: - Persistence (Save to Supabase)
    
    func saveVehicle() async {
        // 1. Final Validation Check
        if let error = validate() {
            await MainActor.run { self.errorMessage = error }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        let sqlDateFormatter = DateFormatter()
        sqlDateFormatter.dateFormat = "yyyy-MM-dd"

        // 2. Construct Payload
        // Note: Ensuring VIN and RC are sanitized/uppercased
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
            // 3. API Request
            let functionURL = URL(string: "\(SUPABASE_URL)/functions/v1/bright-action")!
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 4. Response Handling
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                await MainActor.run { self.isSuccess = true }
            } else {
                // Attempt to extract specific error from Supabase Edge Function
                let errorObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let message = errorObj?["error"] as? String ?? "Server error: \( (response as? HTTPURLResponse)?.statusCode ?? 0)"
                throw NSError(domain: "SupabaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: message])
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
        
        await MainActor.run { self.isLoading = false }
    }
    
    // MARK: - Upload Methods (Storage)
        
    func uploadImage(image: UIImage, type: String) async {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let fileName = "\(UUID().uuidString).jpg"
        let bucket = (type == "VEHICLE") ? "vehicle-images" : "vehicle-documents"
        
        do {
            let storage = SupabaseManager.shared.client.storage.from(bucket)
            try await storage.upload(path: fileName, file: data, options: FileOptions(contentType: "image/jpeg"))
            
            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/\(bucket)/\(fileName)"
            
            await MainActor.run {
                switch type {
                case "RC":
                    self.rcURL = publicURL
                    self.rcFileName = "Photo_RC.jpg"
                case "INSURANCE":
                    self.insuranceURL = publicURL
                    self.insuranceFileName = "Photo_INS.jpg"
                case "PUC":
                    self.pucURL = publicURL
                    self.pucFileName = "Photo_PUC.jpg"
                case "VEHICLE":
                    self.vehicleImageURL = publicURL
                default: break
                }
            }
        } catch {
            await MainActor.run { self.errorMessage = "Upload failed: \(error.localizedDescription)" }
        }
    }

    func uploadFile(fileURL: URL, type: String) async {
        do {
            // Start accessing security-scoped resource if coming from DocumentPicker
            let data = try Data(contentsOf: fileURL)
            let fileName = "\(UUID().uuidString).\(fileURL.pathExtension)"
            let storage = SupabaseManager.shared.client.storage.from("vehicle-documents")
            
            try await storage.upload(path: fileName, file: data)
            
            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/vehicle-documents/\(fileName)"
            
            await MainActor.run {
                let originalName = fileURL.lastPathComponent
                switch type {
                case "RC":
                    self.rcURL = publicURL
                    self.rcFileName = originalName
                case "INSURANCE":
                    self.insuranceURL = publicURL
                    self.insuranceFileName = originalName
                case "PUC":
                    self.pucURL = publicURL
                    self.pucFileName = originalName
                default: break
                }
            }
        } catch {
            await MainActor.run { self.errorMessage = "File error: \(error.localizedDescription)" }
        }
    }
}
