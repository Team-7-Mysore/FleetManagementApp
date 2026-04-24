import SwiftUI
import Combine
import Foundation
import Supabase

// MARK: - UI Models (Renamed to avoid conflict with MaintenanceTask)
struct MaintenanceAlert: Identifiable {
    let id: UUID
    let unitNumber: String
    let serviceType: String
    let icon: String
    let iconBgColor: Color
    let iconForegroundColor: Color
    let status: MaintenanceAlertStatus // Renamed
    let timeRemaining: String
}

// Renamed from MaintenanceStatus to MaintenanceAlertStatus
enum MaintenanceAlertStatus: String {
    case overdue = "OVERDUE"
    case dueSoon = "DUE SOON"
    
    var color: Color {
        self == .overdue ? Color(red: 0.9, green: 0.4, blue: 0.4) : Color(red: 0.9, green: 0.6, blue: 0.3)
    }
}

@MainActor
final class FleetListViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var maintenanceAlerts: [MaintenanceAlert] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var errorMessage: String?
    
    var totalVehiclesCount: Int {
        vehicles.count
    }
    
 
    func deleteVehicle(_ vehicle: Vehicle) async {
        do {
            // ✅ DELETE FROM SUPABASE
            try await SupabaseManager.shared.client
                .from("vehicles")
                .delete()
                .eq("vehicle_id", value: vehicle.id.uuidString)
                .execute()

          
            DispatchQueue.main.async {
                self.vehicles.removeAll { $0.id == vehicle.id }
            }

        } catch {
            print("❌ Error deleting vehicle: \(error)")
        }
    }
    func fetchVehicles() async {
        isLoading = true
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
                .order("vehicle_name", ascending: true)
                .execute()

            // Parsing logic usually happens here via parseVehicles helper
            self.vehicles = try Self.parseVehicles(from: response.data)
            
            await checkAndUpdateCompletedWorkOrders()
            
            isLoading = false
        } catch {
            print("❌ Supabase Fetch Error: \(error)")
            isLoading = false
        }
    }
    
    func checkAndUpdateCompletedWorkOrders() async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("work_orders")
                .select("vehicle_vin, status")
                .eq("status", value: "Completed")
                .execute()
            
            guard let rows = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else { return }
            
            for row in rows {
                guard let vin = row["vehicle_vin"] as? String else { continue }
                
                try await SupabaseManager.shared.client
                    .from("vehicles")
                    .update(["status": "active"])
                    .eq("vin", value: vin)
                    .eq("status", value: "under_maintenance")
                    .execute()
            }
        } catch {
            print("❌ Error checking completed work orders: \(error)")
        }
    }

    func fetchMaintenanceAlerts() async {
        isLoading = true
        do {
            let response = try await SupabaseManager.shared.client
                .from("maintenance_issues")
                .select("""
                    *,
                    vehicles (
                        number_plate,
                        vehicle_name
                    )
                """)
                .neq("status", value: "completed")
                .order("created_at", ascending: false)
                .execute()

            let rows = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] ?? []
            
            self.maintenanceAlerts = rows.compactMap { row in
                let vehicleData = row["vehicles"] as? [String: Any]
                let plate = vehicleData?["number_plate"] as? String ?? "Unknown"
                let desc = row["description"] as? String ?? "No Description"
                let statusStr = row["status"] as? String ?? "pending"
                
                // Using the new unique UI status name
                let uiStatus: MaintenanceAlertStatus = (statusStr == "pending") ? .overdue : .dueSoon
                
                return MaintenanceAlert(
                    id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
                    unitNumber: plate,
                    serviceType: desc,
                    icon: uiStatus == .overdue ? "wrench.and.screwdriver.fill" : "clock.badge.exclamationmark.fill",
                    iconBgColor: uiStatus == .overdue ? Color(red: 0.98, green: 0.9, blue: 0.9) : Color(red: 0.98, green: 0.95, blue: 0.88),
                    iconForegroundColor: uiStatus.color,
                    status: uiStatus,
                    timeRemaining: uiStatus == .overdue ? "Urgent" : "Active"
                )
            }
            isLoading = false
        } catch {
            print("❌ Alert Fetch Error: \(error)")
            isLoading = false
        }
    }
}

// MARK: - Parsing Helpers
private extension FleetListViewModel {
    static func parseVehicles(from data: Data) throws -> [Vehicle] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: "FleetList", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }

        return rows.compactMap { row in
            let idString = stringValue(row["vehicle_id"])
            guard let idString = idString,
                  let id = UUID(uuidString: idString) else { 
                return nil 
            }
            
            let vehicleType = preferredText(stringValue(row["vehicle_type"]), fallback: nil, defaultValue: "Unknown")
            let vehicleName = preferredText(stringValue(row["vehicle_name"]), fallback: stringValue(row["number_plate"]), defaultValue: "Unnamed Vehicle")

            var vehicle = Vehicle(
                id: id,
                name: vehicleName,
                registrationNumber: preferredText(stringValue(row["number_plate"]), fallback: nil, defaultValue: "No Plate"),
                brand: stringValue(row["brand"]),
                model: stringValue(row["model"]),
                imageURL: stringValue(row["image_url"]),
                vehicleType: vehicleType,
                fuelType: stringValue(row["fuel_type"]),
                modelYear: stringValue(row["model_year"])
            )
            vehicle.vin = stringValue(row["vin"]) ?? ""
            vehicle.rcNumber = stringValue(row["registration_no"]) ?? ""
            vehicle.registrationDate = stringValue(row["registration_date"]) ?? ""
            vehicle.rcExpiryDate = stringValue(row["rc_expiry_date"]) ?? ""
            vehicle.pucExpiryDate = stringValue(row["puc_expiry_date"]) ?? ""
            vehicle.status = stringValue(row["status"])
            return vehicle
        }
    }

    static func stringValue(_ value: Any?) -> String? {
        if value is NSNull || value == nil { return nil }
        return "\(value!)"
    }

    static func preferredText(_ primary: String?, fallback: String?, defaultValue: String) -> String {
        if let p = primary, !p.trimmingCharacters(in: .whitespaces).isEmpty { return p }
        if let f = fallback, !f.trimmingCharacters(in: .whitespaces).isEmpty { return f }
        return defaultValue
    }
}
