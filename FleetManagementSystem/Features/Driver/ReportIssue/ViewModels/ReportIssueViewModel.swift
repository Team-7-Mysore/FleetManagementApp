import Foundation
import Combine
import SwiftUI
import Supabase

@MainActor
class ReportIssueViewModel: ObservableObject {
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var submitSuccess = false
    
    let user: User
    let vehicle: Vehicle?
    // Added trip if the driver has an active trip
    var activeTripId: UUID?
    
    init(user: User, vehicle: Vehicle?) {
        self.user = user
        self.vehicle = vehicle
    }
    
    func submitReport(category: String, severity: String, description: String) async {
        guard let vehicleId = vehicle?.id else {
            self.errorMessage = "Missing vehicle information."
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            // First, retrieve the driver_id for the current user
            let driverRes = try await SupabaseManager.shared.client
                .from("drivers")
                .select("driver_id")
                .eq("user_id", value: user.id)
                .single()
                .execute()
            
            struct DriverResponse: Decodable {
                let driver_id: String
            }
            
            let driverData = try JSONDecoder().decode(DriverResponse.self, from: driverRes.data)
            guard let driverId = UUID(uuidString: driverData.driver_id) else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Driver ID format."])
            }
            
            // Map UI categories to database constraints
            let mappedCategory = mapCategory(category)
            let mappedSeverity = severity.lowercased() // Low -> low, Medium -> medium, Critical -> critical
            
            let report = DriverReportDTO(
                driverId: driverId,
                vehicleId: vehicleId,
                tripId: activeTripId,
                category: mappedCategory,
                severity: mappedSeverity,
                description: description
            )
            
            try await SupabaseManager.shared.client
                .from("driver_reports")
                .insert(report)
                .execute()
                
            self.submitSuccess = true
            
        } catch {
            print("❌ Report submission error:", error)
            self.errorMessage = "Error: \(error.localizedDescription)"
        }
        
        isSubmitting = false
    }
    
    private func mapCategory(_ uiCategory: String) -> String {
        return uiCategory.lowercased()
    }
}
