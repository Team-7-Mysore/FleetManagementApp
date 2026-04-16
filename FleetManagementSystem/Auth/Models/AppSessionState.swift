import Foundation

enum AppSessionState: Equatable {
    case signedOut
    case signedIn(AppUserSession)
}
