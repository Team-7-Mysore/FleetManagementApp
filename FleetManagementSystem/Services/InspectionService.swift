import Foundation

// MARK: - Inspection Service
final class InspectionService {
    static let shared = InspectionService()
    private let store = MockDataStore.shared

    private init() {}

    func currentInspection(forDriver driverId: UUID) -> Inspection? {
        store.inspections.first {
            $0.driverId == driverId && !$0.isSubmitted
        }
    }

    func inspectionHistory(forDriver driverId: UUID) -> [Inspection] {
        store.inspections
            .filter { $0.driverId == driverId && $0.isSubmitted }
            .sorted { $0.date > $1.date }
    }

    func updateItemStatus(inspectionId: UUID, itemId: UUID, status: InspectionItemStatus, notes: String) {
        guard let inspIdx = store.inspections.firstIndex(where: { $0.id == inspectionId }),
              let itemIdx = store.inspections[inspIdx].items.firstIndex(where: { $0.id == itemId })
        else { return }
        store.inspections[inspIdx].items[itemIdx].status = status
        store.inspections[inspIdx].items[itemIdx].notes = notes
    }

    func submitInspection(id: UUID, notes: String) {
        guard let idx = store.inspections.firstIndex(where: { $0.id == id }) else { return }
        store.inspections[idx].isSubmitted = true
        store.inspections[idx].overallNotes = notes
    }

    func createNewInspection(vehicleId: UUID, driverId: UUID, type: InspectionType) -> Inspection {
        let items = defaultInspectionItems()
        let inspection = Inspection(
            id: UUID(), vehicleId: vehicleId, driverId: driverId,
            type: type, date: Date(), items: items,
            overallNotes: "", isSubmitted: false
        )
        store.inspections.append(inspection)
        return inspection
    }

    private func defaultInspectionItems() -> [InspectionItem] {
        let checklist: [(String, String)] = [
            ("Tires & Wheels", "Exterior"),
            ("Brakes", "Safety"),
            ("Lights & Signals", "Exterior"),
            ("Mirrors", "Exterior"),
            ("Horn", "Safety"),
            ("Windshield & Wipers", "Exterior"),
            ("Fluid Levels", "Engine"),
            ("Seat Belt", "Safety")
        ]
        return checklist.map {
            InspectionItem(id: UUID(), name: $0.0, category: $0.1, status: .pending, notes: "")
        }
    }
}
