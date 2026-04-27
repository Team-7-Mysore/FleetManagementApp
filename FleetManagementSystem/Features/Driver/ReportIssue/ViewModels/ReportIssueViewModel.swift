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

            // Fetch managers to notify them
            struct ManagerResponse: Decodable { let user_id: UUID }
            print("Fetching managers...")
            let managersRes = try await SupabaseManager.shared.client
                .from("users")
                .select("user_id")
                .eq("role", value: "fleet_manager")
                .execute()

            let managers = try JSONDecoder().decode([ManagerResponse].self, from: managersRes.data)
            print("Found \(managers.count) managers.")

            let vehicleName = vehicle?.name ?? vehicle?.registrationNumber ?? "a vehicle"
            let title = "New Issue Reported"
            let message = issues.count > 1
                ? "\(issues.count) issues reported for \(vehicleName)."
                : "Issue reported for \(vehicleName): \(issues.first?.category ?? "")."

            let notifications = managers.map { manager -> NotificationInsertDTO in
                return NotificationInsertDTO(
                    recipient_id: manager.user_id,
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
        return uiCategory.lowercased()
    }
}
