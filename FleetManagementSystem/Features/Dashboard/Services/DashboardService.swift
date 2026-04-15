import Foundation

protocol DashboardServiceProtocol {
    func fetchVehicles() async throws -> [Vehicle]
}

final class DashboardService: DashboardServiceProtocol {
    func fetchVehicles() async throws -> [Vehicle] {
        try await Task.sleep(for: .milliseconds(400))

        return [
        ]
    }
}
