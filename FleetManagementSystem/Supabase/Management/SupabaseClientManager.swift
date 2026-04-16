import Foundation

final class SupabaseClientManager {
    static let shared = SupabaseClientManager()

    private init() {}

    var isConfigured: Bool {
        false
    }
}
