import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var vehicles: [Vehicle] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: DashboardServiceProtocol

    init(service: DashboardServiceProtocol = DashboardService()) {
        self.service = service
    }

    func loadDashboard() async {
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
