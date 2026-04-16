import Foundation

enum AuthError: LocalizedError {
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "The email or password is incorrect for this role."
        }
    }
}
