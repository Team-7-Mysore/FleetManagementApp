import Foundation
import Combine

@MainActor
final class FleetManagerDashboardViewModel: ObservableObject {
    @Published private(set) var vehicles: [Vehicle] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: FleetService

    init(service: FleetService = FleetService()) {
        self.service = service
    }

    func loadVehicles() async {
        isLoading = true
        errorMessage = nil

        do {
            vehicles = try await service.fetchVehicles()
        } catch {
            errorMessage = "Please try again."
        }

        isLoading = false
    }
}
