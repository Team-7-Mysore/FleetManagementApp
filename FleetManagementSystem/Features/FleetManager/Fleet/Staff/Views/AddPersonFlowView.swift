import SwiftUI

struct AddPersonFlowView: View {

    @StateObject private var model = StaffRegistrationModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if model.accountCreated {
                // ——— Success ———
                AddStaffSuccessView(model: model) {
                    model.reset()
                    dismiss()
                }
            } else {
                if model.currentStep == 1 {
                    AddStaffModalView(
                        model: model,
                        onDismiss: { dismiss() },
                        onNext: {
                            withAnimation {
                                model.currentStep = 2
                            }
                        }
                    )
                } else {
                    AddStaffReviewView(
                        model: model,
                        onBack: {
                            withAnimation {
                                model.currentStep = 1
                            }
                        },
                        onSubmit: {
                            // ✅ THIS IS THE ONLY CHANGE
                            model.accountCreated = true
                        }
                    )
                }
            }

            // ——— Loading Overlay ———
            if model.isCreatingAccount {
                Color.black.opacity(0.35).ignoresSafeArea()

                VStack(spacing: 18) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.4)

                    Text("Creating Account…")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(36)
                .background(Color.blue.opacity(0.9))
                .cornerRadius(20)
                .shadow(radius: 20)
            }
        }
    }
}

#Preview {
    AddPersonFlowView()
}
