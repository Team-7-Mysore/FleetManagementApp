import Foundation
import Combine

// MARK: - Inspection ViewModel
@MainActor
final class InspectionViewModel: ObservableObject {
    @Published var currentInspection: Inspection?
    @Published private(set) var history: [Inspection] = []
    @Published var selectedTab: InspectionTab = .current

    private let user: User
    private let service = InspectionService.shared
    private let vehicleService = VehicleService.shared
    private let tripService = TripService.shared

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

    func updateItem(itemId: UUID, status: InspectionItemStatus, notes: String = "") {
        guard let inspection = currentInspection else { return }
        service.updateItemStatus(inspectionId: inspection.id, itemId: itemId, status: status, notes: notes)
        loadData()
    }

    func submitInspection(notes: String) {
        guard let inspection = currentInspection else { return }
        service.submitInspection(id: inspection.id, notes: notes)
        loadData()
    }

    func startNewInspection(type: InspectionType) {
        guard let vehicle = vehicleService.assignedVehicle(forDriver: user.id) else { return }
        _ = service.createNewInspection(vehicleId: vehicle.id, driverId: user.id, type: type)
        loadData()
    }

    func submitAndStartTrip(notes: String, trip: Trip) {
        guard let inspection = currentInspection else { return }
        service.submitInspection(id: inspection.id, notes: notes)
        tripService.startTrip(id: trip.id)
        loadData()
    }

    var canSubmit: Bool {
        guard let inspection = currentInspection else { return false }
        return inspection.pendingCount == 0
    }
}
