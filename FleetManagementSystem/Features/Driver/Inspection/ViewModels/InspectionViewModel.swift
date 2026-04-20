import Foundation
import Combine
import Supabase

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

    // MARK: - Auto-start inspection when coming from a trip
    func loadDataAndAutoStart(for trip: Trip?) {
        currentInspection = service.currentInspection(forDriver: user.id)
        history = service.inspectionHistory(forDriver: user.id)

        guard trip != nil, currentInspection == nil else { return }

        // Use trip's vehicleId if available, else fall back to placeholder
        // InspectionService only needs vehicleId for record-keeping,
        // all checklist items are hardcoded so this always works
        let vehicleId = (trip?.vehicleId != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
            ? (trip?.vehicleId ?? UUID())
            : UUID()

        _ = service.createNewInspection(
            vehicleId: vehicleId,
            driverId: user.id,
            type: .preTrip
        )

        // Reload after creation
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
        // Always works — vehicle ID is just for record keeping
        let vehicleId = UUID()
        _ = service.createNewInspection(
            vehicleId: vehicleId,
            driverId: user.id,
            type: type
        )
        loadData()
    }

    func submitAndStartTrip(notes: String, trip: Trip) {
        guard let inspection = currentInspection else { return }
        service.submitInspection(id: inspection.id, notes: notes)

        // Update trip status in Supabase
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("trips")
                    .update(["status": "active"])
                    .eq("trip_id", value: trip.id.uuidString)
                    .execute()
            } catch {
                print("❌ submitAndStartTrip error:", error)
            }
        }
        loadData()
    }

    var canSubmit: Bool {
        guard let inspection = currentInspection else { return false }
        return inspection.pendingCount == 0
    }
}
