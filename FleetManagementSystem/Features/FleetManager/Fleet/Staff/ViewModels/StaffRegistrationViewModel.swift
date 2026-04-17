
//
//  StaffRegistrationViewModel.swift
//  FleetManagementSystem
//
//  View-model wrapper – thin layer kept separate so the Views
//  remain lightweight and the model is the source of truth.
//

import Foundation
import Combine

final class StaffRegistrationViewModel: ObservableObject {

    @Published var model = StaffRegistrationModel()

    // Convenience pass-throughs for bindings
    var firstName:    String { get { model.firstName    } set { model.firstName    = newValue } }
    var lastName:     String { get { model.lastName     } set { model.lastName     = newValue } }
    var email:        String { get { model.email        } set { model.email        = newValue } }
    var selectedRole: StaffRole? { get { model.selectedRole } set { model.selectedRole = newValue } }

    var generatedUsername: String { model.generatedUsername }
    var isFormValid:       Bool   { model.isFormValid       }
    var isCreatingAccount: Bool   { model.isCreatingAccount }
    var accountCreated:    Bool   { model.accountCreated    }
    var currentStep:       Int    { get { model.currentStep } set { model.currentStep = newValue } }

    func createAccount(completion: @escaping () -> Void) {
        model.createAccount(completion: completion)
    }

    func reset() { model.reset() }
}
