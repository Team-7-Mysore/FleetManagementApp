
//
//  StaffRegistrationViewModel.swift
//  FleetManagementSystem
//
//  Thin ViewModel wrapper — keeps Views lightweight.
//

import Foundation
import Combine

final class StaffRegistrationViewModel: ObservableObject {

    @Published var model = StaffRegistrationModel()

    // Convenience pass-throughs
    var firstName:     String     { get { model.firstName     } set { model.firstName     = newValue } }
    var lastName:      String     { get { model.lastName      } set { model.lastName      = newValue } }
    var email:         String     { get { model.email         } set { model.email         = newValue } }
    var phoneNo:       String     { get { model.phoneNo       } set { model.phoneNo       = newValue } }
    var selectedRole:  StaffRole? { get { model.selectedRole  } set { model.selectedRole  = newValue } }

    var generatedUsername: String  { model.generatedUsername  }
    var displayUsername:   String  { model.displayUsername    }
    var isFormValid:       Bool    { model.isFormValid        }
    var isCreatingAccount: Bool    { model.isCreatingAccount  }
    var accountCreated:    Bool    { model.accountCreated     }
    var errorMessage:      String? { model.errorMessage       }
    var currentStep:       Int     { get { model.currentStep  } set { model.currentStep   = newValue } }

    func createAccount(completion: @escaping () -> Void) {
        model.createAccount(completion: completion)
    }

    func reset() { model.reset() }
}
