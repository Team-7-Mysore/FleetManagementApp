import Foundation
import Combine
import Supabase

// MARK: - Inspection Service (in-memory, local)
// Handles all inspection logic locally since inspections table only stores metadata
final class InspectionService {
    static let shared = InspectionService()
    private init() {}

    private var inspections: [Inspection] = []

    func currentInspection(forDriver driverId: UUID) -> Inspection? {
        inspections.first { $0.driverId == driverId && !$0.isSubmitted }
    }

    func inspectionHistory(forDriver driverId: UUID) -> [Inspection] {
        inspections.filter { $0.driverId == driverId && $0.isSubmitted }
    }

    func createNewInspection(vehicleId: UUID, driverId: UUID, type: InspectionType) -> Inspection {
        let items = defaultChecklistItems(for: type)
        let inspection = Inspection(
            id: UUID(),
            vehicleId: vehicleId,
            driverId: driverId,
            type: type,
            date: Date(),
            items: items,
            overallNotes: "",
            isSubmitted: false
        )
        inspections.append(inspection)
        return inspection
    }

    func updateItemStatus(inspectionId: UUID, itemId: UUID, status: InspectionItemStatus, notes: String = "") {
        guard let inspIdx = inspections.firstIndex(where: { $0.id == inspectionId }) else { return }
        guard let itemIdx = inspections[inspIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        inspections[inspIdx].items[itemIdx].status = status
        if !notes.isEmpty {
            inspections[inspIdx].items[itemIdx].notes = notes
        }
    }

    func submitInspection(id: UUID, notes: String) {
        guard let idx = inspections.firstIndex(where: { $0.id == id }) else { return }
        inspections[idx].overallNotes = notes
        inspections[idx].isSubmitted = true
    }

    private func defaultChecklistItems(for type: InspectionType) -> [InspectionItem] {
        let prefix = type == .preTrip ? "Pre-trip: " : "Post-trip: "
        return [
            InspectionItem(id: UUID(), name: "\(prefix)Tires", category: "Exterior", status: .pending, notes: ""),
            InspectionItem(id: UUID(), name: "\(prefix)Lights", category: "Exterior", status: .pending, notes: ""),
            InspectionItem(id: UUID(), name: "\(prefix)Mirrors", category: "Exterior", status: .pending, notes: ""),
            InspectionItem(id: UUID(), name: "\(prefix)Brakes", category: "Mechanical", status: .pending, notes: ""),
            InspectionItem(id: UUID(), name: "\(prefix)Engine Oil", category: "Mechanical", status: .pending, notes: ""),
            InspectionItem(id: UUID(), name: "\(prefix)Fuel Level", category: "Mechanical", status: .pending, notes: ""),
            InspectionItem(id: UUID(), name: "\(prefix)Seat Belts", category: "Safety", status: .pending, notes: ""),
            InspectionItem(id: UUID(), name: "\(prefix)Fire Extinguisher", category: "Safety", status: .pending, notes: ""),
            InspectionItem(id: UUID(), name: "\(prefix)Documents", category: "Administrative", status: .pending, notes: ""),
        ]
    }
}

// MARK: - Inspection ViewModel
@MainActor
final class InspectionViewModel: ObservableObject {
    @Published var currentInspection: Inspection?
    @Published private(set) var history: [Inspection] = []
    @Published var selectedTab: InspectionTab = .current

    private let user: User
    private let service = InspectionService.shared

    enum InspectionTab: String, CaseIterable, Identifiable {
        case current = "Current"
        case history = "History"
        var id: String { rawValue }
    }

    init(user: User) {
        self.user = user
    }

    func loadData() {
        currentInspection = service.currentInspection(forDriver: user.id)
        history = service.inspectionHistory(forDriver: user.id)
    }

    func loadDataAndAutoStart(for trip: TripMap?, type: InspectionType = .preTrip) {
        currentInspection = service.currentInspection(forDriver: user.id)
        history = service.inspectionHistory(forDriver: user.id)

        guard trip != nil, currentInspection == nil else { return }

        let vehicleId = (trip?.vehicleId != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
            ? (trip?.vehicleId ?? UUID())
            : UUID()

        _ = service.createNewInspection(
            vehicleId: vehicleId,
            driverId: user.id,
            type: type
        )

        currentInspection = service.currentInspection(forDriver: user.id)
        history = service.inspectionHistory(forDriver: user.id)
    }

    func updateItem(itemId: UUID, status: InspectionItemStatus, notes: String = "") {
        guard let inspection = currentInspection else { return }
        service.updateItemStatus(
            inspectionId: inspection.id,
            itemId: itemId,
            status: status,
            notes: notes
        )
        loadData()
    }

    func submitInspection(notes: String) {
        guard let inspection = currentInspection else { return }
        service.submitInspection(id: inspection.id, notes: notes)
        loadData()
    }

    func startNewInspection(type: InspectionType) {
        let vehicleId = UUID()
        _ = service.createNewInspection(
            vehicleId: vehicleId,
            driverId: user.id,
            type: type
        )
        loadData()
    }

    func submitAndStartTrip(notes: String, trip: TripMap) {
        guard let inspection = currentInspection else { return }
        service.submitInspection(id: inspection.id, notes: notes)

        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("trips")
                    .update([
                        "status": "in_progress",
                        "start_time": ISO8601DateFormatter().string(from: Date())
                    ])
                    .eq("trip_id", value: trip.id.uuidString)
                    .execute()
            } catch {
                print("❌ submitAndStartTrip error:", error)
            }
        }
        loadData()
    }

    func submitAndCompleteTrip(notes: String, trip: TripMap) async -> Bool {
        guard let inspection = currentInspection else { return false }
        service.submitInspection(id: inspection.id, notes: notes)

        do {
            let completedAt = ISO8601DateFormatter().string(from: Date())

            try await SupabaseManager.shared.client
                .from("trips")
                .update([
                    "status": "completed",
                    "end_time": completedAt
                ])
                .eq("trip_id", value: trip.id.uuidString)
                .execute()
            let emptyID = "00000000-0000-0000-0000-000000000000"
            let candidateVehicleId = trip.vehicleId.uuidString

            if !candidateVehicleId.isEmpty, candidateVehicleId != emptyID {
                do {
                    try await SupabaseManager.shared.client
                        .from("vehicles")
                        .update(["status": "unassigned"])
                        .eq("vehicle_id", value: candidateVehicleId)
                        .execute()
                } catch {
                    print("⚠️ vehicle unassign update failed:", error)
                }
            }

            loadData()
            return true
        } catch {
            print("❌ submitAndCompleteTrip error:", error)
            loadData()
            return false
        }
    }

    var canSubmit: Bool {
        guard let inspection = currentInspection else { return false }
        return inspection.pendingCount == 0
    }
}
