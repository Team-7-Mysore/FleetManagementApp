import Foundation
import Combine

import SwiftUI

// MARK: - App Routes
enum AppRoute: Hashable {
    case activeTrip(Trip)
    case vehicleInspection(Trip?)
}

// MARK: - App Router
// Controls top-level navigation: Login → Role-based Tab View, plus path-based routing.

@MainActor
final class AppRouter: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var path = NavigationPath()

    private let authService = AuthService.shared

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signIn(email: email, password: password)
            currentUser = user
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        currentUser = nil
        isLoggedIn = false
    }
}
