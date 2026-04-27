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

            // Batch insert all reports and get the inserted rows back to get the IDs
            let response: [DriverReport] = try await SupabaseManager.shared.client
                .from("driver_reports")
                .insert(reports)
                .select()
                .execute()
                .value

            // Notify Fleet Managers
            await notifyFleetManagers(
                for: reports, 
                insertedId: response.first?.id,
                vehicleName: vehicle?.name ?? vehicle?.registrationNumber ?? "Unknown Vehicle"
            )

            self.submitSuccess = true

        } catch {
            print("❌ Report submission error:", error)
            self.errorMessage = "Error: \(error.localizedDescription)"
        }

        isSubmitting = false
    }

    private func notifyFleetManagers(for reports: [DriverReportDTO], insertedId: UUID?, vehicleName: String) async {
        do {
            // 1. Fetch all fleet managers
            let managers: [AppUser] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("role", value: "fleet_manager")
                .execute()
                .value
            
            guard !managers.isEmpty else { return }
            
            // 2. Create a notification for each manager
            for manager in managers {
                var notificationData: [String: AnyEncodable] = [
                    "recipient_id": AnyEncodable(manager.id),
                    "sender_id": AnyEncodable(user.id),
                    "type": AnyEncodable("Driver Report"),
                    "title": AnyEncodable("New Issue Reported"),
                    "message": AnyEncodable("Driver \(user.email ?? "unknown") reported \(reports.count) issue(s) for \(vehicleName)."),
                    "is_read": AnyEncodable(false)
                ]
                
                if let reportId = insertedId {
                    notificationData["related_entity_id"] = AnyEncodable(reportId)
                }
                
                _ = try? await SupabaseManager.shared.client
                    .from("notifications")
                    .insert(notificationData)
                    .execute()
            }
        } catch {
            print("🚨 Failed to notify fleet managers: \(error)")
        }
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
