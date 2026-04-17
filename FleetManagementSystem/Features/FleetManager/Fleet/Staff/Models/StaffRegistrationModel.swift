
//
//  StaffRegistrationModel.swift
//  FleetManagementSystem
//
//  Data model for the Add Person / Staff onboarding flow.
//  Inserts directly into public.users via Supabase on confirm.
//

import Foundation
import Combine
import Supabase

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

    /// Matches the `user_role` enum values in the DB
    var dbValue: String {
        switch self {
        case .driver:      return "driver"
        case .maintenance: return "maintenance"
        }
    }
}

// MARK: - Supabase Insert Payload

private struct UserInsert: Encodable {
    let name:       String
    let email:      String
    let role:       String
    let phone_no:   String?
    let created_by: String
    let username:   String
}

// MARK: - Model

class StaffRegistrationModel: ObservableObject {

    // Step 1 — Basic Info & Role
    @Published var firstName:    String     = ""
    @Published var lastName:     String     = ""
    @Published var email:        String     = ""
    @Published var phoneNo:      String     = ""
    @Published var selectedRole: StaffRole? = nil

    // Auto-generated username (no "@" prefix stored in DB)
    var generatedUsername: String {
        guard !firstName.isEmpty else { return "" }
        let base = (firstName + lastName)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return base.isEmpty ? "" : base
    }

    /// Display version shown in UI (with @ prefix)
    var displayUsername: String {
        generatedUsername.isEmpty ? "" : "@\(generatedUsername)"
    }

    var fullName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }

    // Navigation
    @Published var currentStep:       Int    = 1
    @Published var isCreatingAccount: Bool   = false
    @Published var accountCreated:    Bool   = false
    @Published var errorMessage:      String? = nil

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

    // MARK: Account Creation — Supabase insert into public.users

    /// Admin UUID who is creating the staff account
    private let adminUserId = "c1ebd8dd-2a0d-458c-ba34-b1d3fc550f13"

    func createAccount(completion: @escaping () -> Void) {
        guard let role = selectedRole else { return }

        isCreatingAccount = true
        errorMessage      = nil

        let payload = UserInsert(
            name:       fullName,
            email:      email.lowercased().trimmingCharacters(in: .whitespaces),
            role:       role.dbValue,
            phone_no:   phoneNo.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phoneNo.trimmingCharacters(in: .whitespaces),
            created_by: adminUserId,
            username:   generatedUsername
        )

        Task { @MainActor in
            do {
                try await SupabaseManager.shared.client
                    .from("users")
                    .insert(payload)
                    .execute()

                isCreatingAccount = false
                accountCreated    = true
                completion()
            } catch {
                isCreatingAccount = false
                errorMessage      = error.localizedDescription
            }
        }
    }

    func reset() {
        firstName         = ""
        lastName          = ""
        email             = ""
        phoneNo           = ""
        selectedRole      = nil
        currentStep       = 1
        isCreatingAccount = false
        accountCreated    = false
        errorMessage      = nil
    }
}
