import Foundation

final class FleetService {
    init() {}

    func fetchVehicles() async throws -> [Vehicle] {
        try await Task.sleep(for: .milliseconds(400))
        return []
    }
}
