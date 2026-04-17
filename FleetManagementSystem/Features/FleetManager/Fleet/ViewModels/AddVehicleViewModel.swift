import SwiftUI
import Combine
import Foundation
class AddVehicleViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSuccess = false
    
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
        
        return nil
    }
    func validateStep1() -> String? {
        
        if vehicleName.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Vehicle name is required"
        }
        
        if registrationNumber.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Registration number is required"
        }
        
        return nil
    }
}



extension AddVehicleViewModel {
    func uploadImage(image: UIImage, type: String) async {
        
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        
        let fileName = UUID().uuidString + ".jpg"
        
        let storageURL = "\(SUPABASE_URL)/storage/v1/object/vehicle-documents/\(fileName)"
        
        guard let url = URL(string: storageURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        do {
            _ = try await URLSession.shared.upload(for: request, from: data)
            
            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/vehicle-documents/\(fileName)"
            
            DispatchQueue.main.async {
                switch type {
                case "RC":
                    self.rcURL = publicURL
                case "INSURANCE":
                    self.insuranceURL = publicURL
                case "PUC":
                    self.pucURL = publicURL
                default:
                    break
                }
            }
            
        } catch {
            print("Upload failed:", error)
        }
    }
    
    func uploadFile(fileURL: URL, type: String) async {
        
        let fileExtension = fileURL.pathExtension
        let fileName = UUID().uuidString + "." + fileExtension
        let storageURL = "\(SUPABASE_URL)/storage/v1/object/vehicle-documents/\(fileName)"
        
        guard let url = URL(string: storageURL) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        
        do {
            let data = try Data(contentsOf: fileURL)
            _ = try await URLSession.shared.upload(for: request, from: data)
            
            let publicURL = "\(SUPABASE_URL)/storage/v1/object/public/vehicle-documents/\(fileName)"
            
            DispatchQueue.main.async {
                switch type {
                case "RC":
                    self.rcURL = publicURL
                case "INSURANCE":
                    self.insuranceURL = publicURL
                case "PUC":
                    self.pucURL = publicURL
                default:
                    break
                }
            }
            
        } catch {
            print("Upload failed:", error)
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
        
        guard let url = URL(string: "https://qisdvwaldlghndrudbvr.supabase.co/functions/v1/bright-action") else {
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        // ✅ CLEAN DOCUMENT ARRAY (no empty URLs)
        let documents = [
            rcURL != nil ? ["type": "RC", "url": rcURL!] : nil,
            insuranceURL != nil ? ["type": "INSURANCE", "url": insuranceURL!] : nil,
            pucURL != nil ? ["type": "PUC", "url": pucURL!] : nil
        ].compactMap { $0 }
        
        let payload: [String: Any] = [
            "vehicleName": vehicleName,
            "registrationNumber": registrationNumber,
            "vin": UUID().uuidString,
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
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("Status Code:", httpResponse.statusCode)
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("Response Body:", responseString)
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                
                DispatchQueue.main.async {
                    self.isSuccess = true
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to save vehicle"
                }
            }
            
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
