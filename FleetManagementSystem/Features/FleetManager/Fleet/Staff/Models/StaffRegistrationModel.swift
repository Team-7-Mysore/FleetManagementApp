
//
//  StaffRegistrationModel.swift
//  FleetManagementSystem
//
//  Data model for the Add Person / Staff onboarding flow
//

import Foundation
import Combine

// MARK: - Role

enum StaffRole: String, CaseIterable, Identifiable {
    case driver      = "Driver"
    case maintenance = "Maintenance Staff"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .driver:      return "car.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        }
    }

    var description: String {
        switch self {
        case .driver:      return "Manages vehicle operations and deliveries"
        case .maintenance: return "Handles vehicle maintenance and repairs"
        }
    }
}

// MARK: - Model

class StaffRegistrationModel: ObservableObject {

    // Step 1 — Basic Info & Role
    @Published var firstName:     String = ""
    @Published var lastName:      String = ""
    @Published var email:         String = ""
    @Published var selectedRole:  StaffRole? = nil

    // Auto-generated username
    var generatedUsername: String {
        guard !firstName.isEmpty else { return "" }
        let base = (firstName + lastName)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return base.isEmpty ? "" : "@\(base)"
    }

    // Navigation
    @Published var currentStep:       Int  = 1   // 1 = form, 2 = review
    @Published var isCreatingAccount: Bool = false
    @Published var accountCreated:    Bool = false

    // MARK: Validation

    var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        isValidEmail(email) &&
        selectedRole != nil
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }

    // MARK: Account Creation

    func createAccount(completion: @escaping () -> Void) {
        isCreatingAccount = true
        // Simulate backend call / email dispatch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isCreatingAccount = false
            self.accountCreated = true
            completion()
        }
    }

    func reset() {
        firstName     = ""
        lastName      = ""
        email         = ""
        selectedRole  = nil
        currentStep   = 1
        isCreatingAccount = false
        accountCreated    = false
    }
}
