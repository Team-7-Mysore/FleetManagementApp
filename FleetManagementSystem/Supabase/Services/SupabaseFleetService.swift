import Foundation

final class SupabaseFleetService {
    private let manager: SupabaseClientManager

    init(manager: SupabaseClientManager = .shared) {
        self.manager = manager
    }

    func fetchVehicles() async throws -> [Vehicle] {
        _ = manager.isConfigured
        try await Task.sleep(for: .milliseconds(400))
        return []
    }
}
