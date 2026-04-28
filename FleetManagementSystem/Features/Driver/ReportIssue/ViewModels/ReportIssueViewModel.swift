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
    /// Set this if the driver has an active trip
    var activeTripId: UUID?

    init(user: User, vehicle: Vehicle?) {
        self.user = user
        self.vehicle = vehicle
    }

    // MARK: - Submit Multiple Reports
    func submitReports(issues: [IssueEntry]) async {
        guard let vehicleId = vehicle?.id else {
            self.errorMessage = "Missing vehicle information."
            return
        }
        guard !issues.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            // Fetch the driver_id for the current user
            let driverRes = try await SupabaseManager.shared.client
                .from("drivers")
                .select("driver_id")
                .eq("user_id", value: user.id)
                .single()
                .execute()

            struct DriverResponse: Decodable { let driver_id: String }
            let driverData = try JSONDecoder().decode(DriverResponse.self, from: driverRes.data)
            guard let driverId = UUID(uuidString: driverData.driver_id) else {
                throw NSError(domain: "", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid Driver ID format."])
            }

            // Build a DTO for each issue entry
            let reports: [DriverReportDTO] = issues.map { entry in
                DriverReportDTO(
                    driverId: driverId,
                    vehicleId: vehicleId,
                    tripId: activeTripId,
                    category: mapCategory(entry.category),
                    severity: entry.severity.lowercased(),
                    description: entry.description
                )
            }

            // Batch insert all reports in one request
            try await SupabaseManager.shared.client
                .from("driver_reports")
                .insert(reports)
                .execute()

            // Fetch the right manager(s) to notify
            var targetManagerIds: [UUID] = []
            
            // Try to find the manager attached to the active trip
            if let tripId = activeTripId {
                print("Fetching manager for trip: \(tripId)...")
                struct TripResponse: Decodable { let fleet_manager_id: UUID? }
                do {
                    let tripRes = try await SupabaseManager.shared.client
                        .from("trips")
                        .select("fleet_manager_id")
                        .eq("trip_id", value: tripId)
                        .single()
                        .execute()
                    
                    let tripData = try JSONDecoder().decode(TripResponse.self, from: tripRes.data)
                    if let managerId = tripData.fleet_manager_id {
                        targetManagerIds.append(managerId)
                    }
                } catch {
                    print("Could not find a specific manager for the trip, falling back to all managers: \(error)")
                }
            }

            // Fallback: Notify the manager who created the driver profile
            if targetManagerIds.isEmpty {
                print("Fetching the manager who created the driver profile...")
                struct DriverCreatorResponse: Decodable { let created_by: UUID? }
                do {
                    let creatorRes = try await SupabaseManager.shared.client
                        .from("users")
                        .select("created_by")
                        .eq("user_id", value: user.id)
                        .single()
                        .execute()
                    
                    let creatorData = try JSONDecoder().decode(DriverCreatorResponse.self, from: creatorRes.data)
                    if let managerId = creatorData.created_by {
                        targetManagerIds.append(managerId)
                    }
                } catch {
                    print("Could not find creator of the driver profile: \(error)")
                }
            }

            // Final Fallback: Notify all fleet managers if no other manager was found
            if targetManagerIds.isEmpty {
                struct ManagerResponse: Decodable { let user_id: UUID }
                print("Fetching all managers as final fallback...")
                let managersRes = try await SupabaseManager.shared.client
                    .from("users")
                    .select("user_id")
                    .eq("role", value: "fleet_manager")
                    .execute()

                let managers = try JSONDecoder().decode([ManagerResponse].self, from: managersRes.data)
                targetManagerIds = managers.map { $0.user_id }
            }
            
            print("Found \(targetManagerIds.count) managers to notify.")

            let vehicleName = vehicle?.name ?? vehicle?.registrationNumber ?? "a vehicle"
            let title = "New Issue Reported"
            let message = issues.count > 1
                ? "\(issues.count) issues reported for \(vehicleName)."
                : "Issue reported for \(vehicleName): \(issues.first?.category ?? "")."

            let notifications = targetManagerIds.map { managerId -> NotificationInsertDTO in
                return NotificationInsertDTO(
                    recipient_id: managerId,
                    sender_id: user.id,
                    title: title,
                    message: message,
                    type: NotificationType.alert.rawValue,
                    related_entity_id: vehicleId
                )
            }

            if !notifications.isEmpty {
                print("Attempting to insert \(notifications.count) notifications...")
                try await SupabaseManager.shared.client
                    .from("notifications")
                    .insert(notifications)
                    .execute()
                print("Notifications successfully sent to managers!")
            } else {
                print("No managers found. Skipping notification insertion.")
            }

            self.submitSuccess = true

        } catch {
            print("❌ Report submission error:", error)
            self.errorMessage = "Error: \(error.localizedDescription)"
        }

        isSubmitting = false
    }

    // MARK: - Single-report convenience (kept for backward compatibility)
    func submitReport(category: String, severity: String, description: String) async {
        let entry = IssueEntry()
        var e = entry
        e.category = category
        e.severity = severity
        e.description = description
        await submitReports(issues: [e])
    }

    // MARK: - Helpers
    private func mapCategory(_ uiCategory: String) -> String {
        let lower = uiCategory.lowercased()
        if lower == "bodywork" {
            return "body damage"
        }
        return lower
    }
}
