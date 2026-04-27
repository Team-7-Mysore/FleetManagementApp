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
    let explicitVehicleId: UUID?
    /// Set this if the driver has an active trip
    var activeTripId: UUID?

    init(user: User, vehicle: Vehicle?, vehicleId: UUID? = nil, activeTripId: UUID? = nil) {
        self.user = user
        self.vehicle = vehicle
        self.explicitVehicleId = vehicleId
        self.activeTripId = activeTripId
    }

    // MARK: - Submit Multiple Reports
    func submitReports(issues: [IssueEntry]) async {
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

            let resolvedContext = try await resolveVehicleAndTripContext(driverId: driverId)
            let vehicleId = resolvedContext.vehicleId

            if self.activeTripId == nil {
                self.activeTripId = resolvedContext.tripId
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
        switch uiCategory.lowercased() {
        case "mechanical":
            return "mechanical"
        case "electrical":
            return "electrical"
        case "tyre/wheel", "tyre wheel":
            return "tyre/wheel"
        case "fluid leak":
            return "fluid leak"
        case "bodywork", "body damage":
            return "body damage"
        case "safety":
            return "safety"
        default:
            return "other"
        }
    }

    private func resolveVehicleAndTripContext(driverId: UUID) async throws -> (vehicleId: UUID?, tripId: UUID?) {
        let emptyVehicleId = "00000000-0000-0000-0000-000000000000"

        if let explicitVehicleId, explicitVehicleId.uuidString != emptyVehicleId {
            return (explicitVehicleId, activeTripId)
        }

        if let vehicleId = vehicle?.id, vehicleId.uuidString != emptyVehicleId {
            return (vehicleId, activeTripId)
        }

        struct TripContextRow: Decodable {
            let tripId: String
            let vehicleId: String?

            enum CodingKeys: String, CodingKey {
                case tripId = "trip_id"
                case vehicleId = "vehicle_id"
            }
        }

        if let activeTripId {
            let rows: [TripContextRow] = try await SupabaseManager.shared.client
                .from("trips")
                .select("trip_id, vehicle_id")
                .eq("trip_id", value: activeTripId.uuidString)
                .limit(1)
                .execute()
                .value

            if let row = rows.first {
                let vehicleId = row.vehicleId.flatMap(UUID.init(uuidString:))
                if let vehicleId, vehicleId.uuidString != emptyVehicleId {
                    return (vehicleId, UUID(uuidString: row.tripId))
                }
            }
        }

        let rows: [TripContextRow] = try await SupabaseManager.shared.client
            .from("trips")
            .select("trip_id, vehicle_id")
            .eq("driver_id", value: driverId.uuidString)
            .in("status", values: ["in_progress", "assigned"])
            .order("start_time", ascending: false)
            .limit(1)
            .execute()
            .value

        if let row = rows.first {
            let vehicleId = row.vehicleId.flatMap(UUID.init(uuidString:))
            let tripId = UUID(uuidString: row.tripId)
            if let vehicleId, vehicleId.uuidString != emptyVehicleId {
                return (vehicleId, tripId)
            }
        }

        return (nil, nil)
    }
}
