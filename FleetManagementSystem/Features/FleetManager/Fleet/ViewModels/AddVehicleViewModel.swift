import SwiftUI
import Combine
import Foundation
class AddVehicleViewModel: ObservableObject {
    
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
}


extension AddVehicleViewModel {
    
    func uploadFile(fileURL: URL, type: String) async {
        
        let fileName = UUID().uuidString + ".pdf"
        
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
