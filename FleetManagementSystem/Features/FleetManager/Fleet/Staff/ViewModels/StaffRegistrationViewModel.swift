import Foundation
import Combine

final class StaffRegistrationViewModel: ObservableObject {

    @Published var model = StaffRegistrationModel()

    // MARK: - Pass-through bindings

    var firstName:     String     { get { model.firstName     } set { model.firstName     = newValue } }
    var lastName:      String     { get { model.lastName      } set { model.lastName      = newValue } }
    var email:         String     { get { model.email         } set { model.email         = newValue } }
    var phoneNo:       String     { get { model.phoneNo       } set { model.phoneNo       = newValue } }
    var selectedRole:  StaffRole? { get { model.selectedRole  } set { model.selectedRole  = newValue } }

    var isFormValid:       Bool    { model.isFormValid        }
    var isCreatingAccount: Bool    { model.isCreatingAccount  }
    var accountCreated:    Bool    { model.accountCreated     }
    var errorMessage:      String? { model.errorMessage       }

    var currentStep: Int {
        get { model.currentStep }
        set { model.currentStep = newValue }
    }

    // ✅ ONLY keep UI helpers
    func markAccountCreated() {
        model.accountCreated = true
    }

    func reset() {
        model.reset()
    }
}
