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
    @Published var monthlyReminders: [MaintenanceAlert] = []
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
                    puc_expiry_date,
                     created_at
                """)
                .order("created_at", ascending: false)
                .execute()

            let parsedVehicles = try Self.parseVehicles(from: response.data)

                    // 1. Update the vehicle list
                    self.vehicles = parsedVehicles

                    // 2. TRIGGER THE CALCULATION (This was missing)
                    self.calculateMonthlyReminders(from: parsedVehicles)

                    isLoading = false
        } catch {
            print("❌ Supabase Fetch Error: \(error)")
            isLoading = false
        }
    }
    func calculateMonthlyReminders(from vehicles: [Vehicle]) {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        self.monthlyReminders = vehicles.compactMap { vehicle in
            let dateString = vehicle.registrationDate

            guard !dateString.isEmpty, let regDate = formatter.date(from: dateString) else {
                return nil
            }

            let components = calendar.dateComponents([.month], from: regDate, to: today)
            let monthsPassed = components.month ?? 0

            // INTERVAL LOGIC: Show reminder every 6 months (6, 12, 18...)
            // Use 'monthsPassed % 12 == 0' if you want annual service instead
            if monthsPassed > 0 && monthsPassed % 6 == 0 {
                return MaintenanceAlert(
                    id: UUID(),
                    unitNumber: vehicle.registrationNumber,
                    serviceType: "\(monthsPassed)-Month Routine Service",
                    icon: "calendar.badge.clock",
                    iconBgColor: Color.purple.opacity(0.1),
                    iconForegroundColor: .purple,
                    status: .dueSoon,
                    timeRemaining: "Routine"
                )
            }

            return nil // Return nil if the vehicle is not at a 6-month milestone
        }
    }

    func completeWorkOrder(workOrderId: UUID) async {
        do {
            // 1. Update the Work Order Status
            // This triggers the SQL 'tr_on_work_order_completed' on the server
            try await SupabaseManager.shared.client
                .from("work_orders")
                .update(["status": "Completed"]) // ✅ Ensure casing matches your SQL ('Completed')
                .eq("work_order_id", value: workOrderId)
                .execute()

            // 2. Refresh Local UI
            // Since the SQL Trigger modified the 'vehicles' and 'maintenance_issues' tables,
            // we re-fetch everything to show the vehicle as 'Active' and remove the alert.
            await fetchVehicles()
            await fetchMaintenanceAlerts()

            print("✅ Maintenance completion synced successfully.")
        } catch {
            print("❌ Update Error: \(error)")
            self.errorMessage = "Could not complete work order: \(error.localizedDescription)"
        }
    }

    func fetchMaintenanceAlerts() async {
        isLoading = true
        do {
            let response = try await SupabaseManager.shared.client
                .from("maintenance_issues")
                .select("""
                    issue_id,
                    issue_summary,
                    description,
                    status,
                    vehicles (
                        number_plate
                    )
                """)
                // CHANGE: Now we ONLY pull "pending" items.
                // This ignores "in_progress" and "completed".
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()

            let rows = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] ?? []

            self.maintenanceAlerts = rows.compactMap { row in
                let vehicleData = row["vehicles"] as? [String: Any]
                let plate = vehicleData?["number_plate"] as? String ?? "Unknown"
                let title = row["issue_summary"] as? String ?? (row["description"] as? String ?? "Scheduled Service")

                return MaintenanceAlert(
                    id: UUID(uuidString: row["issue_id"] as? String ?? "") ?? UUID(),
                    unitNumber: plate,
                    serviceType: title,
                    icon: "clock.badge.exclamationmark.fill",
                    iconBgColor: Color.blue.opacity(0.1),
                    iconForegroundColor: .blue,
                    status: .dueSoon,
                    timeRemaining: "Scheduled"
                )
            }
            isLoading = false
        } catch {
            print("❌ Fetch Error: \(error)")
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
            guard let idString = stringValue(row["vehicle_id"]),
                  let id = UUID(uuidString: idString) else { return nil }

            var vehicle = Vehicle(
                id: id,
                name: preferredText(stringValue(row["vehicle_name"]), fallback: stringValue(row["number_plate"]), defaultValue: "Unnamed Vehicle"),
                registrationNumber: preferredText(stringValue(row["number_plate"]), fallback: nil, defaultValue: "No Plate"),
                brand: stringValue(row["brand"]),
                model: stringValue(row["model"]),
                imageURL: stringValue(row["image_url"]),
                vehicleType: preferredText(stringValue(row["vehicle_type"]), fallback: nil, defaultValue: "Unknown"),
                fuelType: stringValue(row["fuel_type"]),
                modelYear: stringValue(row["model_year"])
            )
            vehicle.status = stringValue(row["status"])
            vehicle.vin = stringValue(row["vin"]) ?? ""
            vehicle.rcNumber = stringValue(row["registration_no"]) ?? ""
            vehicle.registrationDate = stringValue(row["registration_date"]) ?? ""
            vehicle.rcExpiryDate = stringValue(row["rc_expiry_date"]) ?? ""
            vehicle.pucExpiryDate = stringValue(row["puc_expiry_date"]) ?? ""
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
