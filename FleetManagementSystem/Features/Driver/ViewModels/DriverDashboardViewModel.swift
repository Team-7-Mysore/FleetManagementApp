import Foundation
import Combine

@MainActor
final class DriverDashboardViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var assignment: DriverAssignment?
    @Published private(set) var stats: [DriverStat] = []
    @Published private(set) var trips: [DriverTrip] = []
    @Published var inspectionItems: [DriverInspectionItem] = []
    @Published private(set) var messages: [DriverMessage] = []
    @Published private(set) var activeTripID: UUID?

    private let service: DriverService

    init(service: DriverService? = nil) {
        self.service = service ?? DriverService()
    }

    func loadDashboard() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let data = try await service.fetchDashboardData()
            assignment = data.assignment
            stats = data.stats
            trips = data.trips
            inspectionItems = data.inspectionItems
            messages = data.messages
            activeTripID = data.trips.first(where: { $0.status == .active })?.id
        } catch {
            errorMessage = "We couldn't load the driver dashboard. Please try again."
        }

        isLoading = false
    }

    func toggleInspectionItem(_ item: DriverInspectionItem) {
        guard let index = inspectionItems.firstIndex(where: { $0.id == item.id }) else { return }
        inspectionItems[index].isCompleted.toggle()
    }

    func startTrip(_ trip: DriverTrip) {
        activeTripID = trip.id
    }

    var completedInspectionCount: Int {
        inspectionItems.filter(\.isCompleted).count
    }

    var totalInspectionCount: Int {
        inspectionItems.count
    }
}
