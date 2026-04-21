import SwiftUI
import Combine
import Foundation
import Supabase

private struct VehicleInsert: Encodable {
    let vehicle_name: String
    let number_plate: String
    let brand: String?
    let model_year: Int?
    let vehicle_type: String
    let fuel_type: String?
    let model: String?
    let image_url: String?
}

class AddVehicleViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSuccess = false
    @Published var vin = ""
    @Published var brand = ""
    @Published var modelYear = ""
    @Published var vehicleName = ""
    @Published var registrationNumber = ""
    @Published var vehicleType = "Truck"
    @Published var fuelType = "Diesel"
    
    @Published var manufacturer = ""
    @Published var model = ""
    
    @Published var registrationDate = Date()
    @Published var pucExpiry = Date()
    @Published var rcExpiry = Date()
    
    @Published var rcURL: String?
    @Published var insuranceURL: String?
    @Published var pucURL: String?
    
    @Published var vehicleImageURL: String?
    @Published var localVehicleImage: UIImage?
    
    // Original Filenames for display
    @Published var rcFileName: String?
    @Published var insuranceFileName: String?
    @Published var pucFileName: String?
    var isStep2Valid: Bool {
        return rcURL != nil && insuranceURL != nil
    }
    
    func validate() -> String? {
        if vehicleName.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Vehicle name is required"
        }
        
        if registrationNumber.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Registration number is required"
        }
        
        if rcURL == nil {
            return "RC document is required"
        }
        
        if insuranceURL == nil {
            return "Insurance document is required"
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if calendar.startOfDay(for: rcExpiry) < today {
            return "RC document is expired. Please provide a valid expiry date."
        }
        
        if calendar.startOfDay(for: pucExpiry) < today {
            return "PUC document is expired. Please provide a valid expiry date."
        }
        
        return nil
    }
    var isStep1Valid: Bool {
        !vehicleName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !brand.trimmingCharacters(in: .whitespaces).isEmpty &&
        isValidPlate(registrationNumber) &&
        vin.count == 17
    }

    func validateStep1() -> String? {
        if vehicleName.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Vehicle name is required"
        }
        if registrationNumber.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Registration number is required"
        }
        if !isValidPlate(registrationNumber) {
            return "Enter valid number plate (e.g. KA01AB1234)"
        }
        
        if brand.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Brand is required"
        }
        
        if vin.trimmingCharacters(in: .whitespaces).isEmpty {
            return "VIN is required"
        }
        if vin.count != 17 {
            return "VIN must be exactly 17 characters"
        }
        
        return nil
    }
    func formatPlate(_ input: String) -> String {
        let normalized = input
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        var result = ""
        
        for (index, char) in normalized.enumerated() {
            if index == 2 || index == 4 || index == 6 {
                result.append("-")
            }
            result.append(char)
        }
        
        return result
    }
}



extension AddVehicleViewModel {
    func uploadImage(image: UIImage, type: String) async {
        // Convert image to data
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        
        let fileName = UUID().uuidString + ".jpg"
        
        let bucketName = (type == "VEHICLE") ? "vehicle-images" : "vehicle-documents"
        
        
        let storageURL = "\(SUPABASE_URL)/storage/v1/object/\(bucketName)/\(fileName)"
        
        guard let url = URL(string: storageURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        do {
            
            _ = try await URLSession.shared.upload(for: request, from: data)
            
            
            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/\(bucketName)/\(fileName)"
            
         
            DispatchQueue.main.async {
                switch type {
                case "RC":
                    self.rcURL = publicURL
                    self.rcFileName = "Photo_RC.jpg"
                case "INSURANCE":
                    self.insuranceURL = publicURL
                    self.insuranceFileName = "Photo_Insurance.jpg"
                case "PUC":
                    self.pucURL = publicURL
                    self.pucFileName = "Photo_PUC.jpg"
                case "VEHICLE":
                    self.vehicleImageURL = publicURL
                default:
                    break
                }
            }
            
        } catch {
            print("Upload failed for \(type):", error)
        }
    }
    
    func isValidPlate(_ input: String) -> Bool {
        let normalized = input
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        
        let regex = "^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{3,4}$"
        
        return NSPredicate(format: "SELF MATCHES %@", regex)
            .evaluate(with: normalized)
    }
    func uploadFile(fileURL: URL, type: String) async {
        
        do {
            let data = try Data(contentsOf: fileURL)
            print("File size:", data.count)
            
            let fileExtension = fileURL.pathExtension
            let fileName = UUID().uuidString + "." + fileExtension
            
            let storageURL = "\(SUPABASE_URL)/storage/v1/object/vehicle-documents/\(fileName)"
            
            guard let url = URL(string: storageURL) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
            request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            
            let (responseData, response) = try await URLSession.shared.upload(for: request, from: data)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("UPLOAD STATUS:", httpResponse.statusCode)
            }
            
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("UPLOAD RESPONSE:", responseString)
            }
            
            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/vehicle-documents/\(fileName)"
            
            DispatchQueue.main.async {
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
            print("❌ FILE READ ERROR:", error)
        }
    }
}

extension AddVehicleViewModel {
    
    func saveVehicle() async {
        if let error = validate() {
            DispatchQueue.main.async {
                self.errorMessage = error
            }
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }

        do {
            do {
                let newVehicle = VehicleInsert(
                    vehicle_name: vehicleName.trimmingCharacters(in: .whitespacesAndNewlines),
                    number_plate: registrationNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    brand: brand.nilIfBlank,
                    model_year: Int(modelYear.trimmingCharacters(in: .whitespacesAndNewlines)),
                    vehicle_type: vehicleType.trimmingCharacters(in: .whitespacesAndNewlines),
                    fuel_type: fuelType.nilIfBlank,
                    model: model.nilIfBlank,
                    image_url: vehicleImageURL?.nilIfBlank
                )

                try await SupabaseManager.shared.client
                    .from("vehicles")
                    .insert(newVehicle)
                    .execute()
            } catch {
                let errorText = error.localizedDescription.lowercased()
                if errorText.contains("row-level security") {
                    try await saveVehicleViaEdgeFunction()
                } else {
                    throw error
                }
            }

            DispatchQueue.main.async {
                self.isSuccess = true
            }
        } catch {
            print("❌ Failed to save vehicle: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func saveVehicleViaEdgeFunction() async throws {
        guard let url = URL(string: "https://qisdvwaldlghndrudbvr.supabase.co/functions/v1/bright-action") else {
            throw URLError(.badURL)
        }

        let documents = [
            rcURL != nil ? ["type": "RC", "url": rcURL!] : nil,
            insuranceURL != nil ? ["type": "INSURANCE", "url": insuranceURL!] : nil,
            pucURL != nil ? ["type": "PUC", "url": pucURL!] : nil
        ].compactMap { $0 }

        let payload: [String: Any] = [
            "image_url": vehicleImageURL ?? "",
            "vehicleName": vehicleName,
            "registrationNumber": registrationNumber,
            "vin": vin.uppercased(),
            "brand": brand,
            "model_year": Int(modelYear) ?? 0,
            "vehicleType": vehicleType,
            "fuelType": fuelType,
            "manufacturer": manufacturer,
            "model": model,
            "registrationDate": ISO8601DateFormatter().string(from: registrationDate),
            "pucExpiry": ISO8601DateFormatter().string(from: pucExpiry),
            "rcExpiry": ISO8601DateFormatter().string(from: rcExpiry),
            "documents": documents
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Edge function failed"
            throw NSError(domain: "AddVehicle", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: message
            ])
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
