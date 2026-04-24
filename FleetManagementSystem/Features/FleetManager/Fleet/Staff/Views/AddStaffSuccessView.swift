
//
//  AddStaffSuccessView.swift
//  FleetManagementSystem
//
//  Shown after account is created — animated confirmation
//

import SwiftUI

struct AddStaffSuccessView: View {

    @ObservedObject var model: StaffRegistrationModel
    let onDone: () -> Void

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated success icon
            ZStack {
                Circle()
                    .fill(Color.TechBlue
                        .opacity(0.08))
                    .frame(width: 130, height: 130)
                    .scaleEffect(isAnimating ? 1 : 0.4)
                    .opacity(isAnimating ? 1 : 0)

                Circle()
                    .fill(Color.TechBlue.opacity(0.15))
                    .frame(width: 96, height: 96)
                    .scaleEffect(isAnimating ? 1 : 0.4)
                    .opacity(isAnimating ? 1 : 0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color.TechBlue)
                    .scaleEffect(isAnimating ? 1 : 0.01)
                    .rotationEffect(.degrees(isAnimating ? 0 : -90))
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.65), value: isAnimating)

            // Headline
            VStack(spacing: 10) {
                Text("Account Created!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("\(model.firstName) \(model.lastName) has been added as \(model.selectedRole?.rawValue ?? "a staff member").")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : 16)
            .animation(.easeOut(duration: 0.4).delay(0.25), value: isAnimating)

            // Next Steps card
            VStack(alignment: .leading, spacing: 16) {
                Text("What happens next")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                SuccessStepRow(icon: "envelope.fill",    text: "Login credentials sent to \(model.email.isEmpty ? "user's email" : model.email)")
                SuccessStepRow(icon: "lock.rotation",    text: "User prompted to reset password on first login")
                SuccessStepRow(icon: "square.grid.2x2", text: "\(model.selectedRole?.rawValue ?? "Role") dashboard access granted automatically")
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .padding(.horizontal, 24)
            .opacity(isAnimating ? 1 : 0)
            .offset(y: isAnimating ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(0.4), value: isAnimating)

            Spacer()

            // Done
            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.TechBlue)
                    .cornerRadius(25)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .opacity(isAnimating ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.55), value: isAnimating)
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .onAppear { isAnimating = true }
    }
}

// MARK: - Step Row

private struct SuccessStepRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.TechBlue)
                .font(.system(size: 18))
                .frame(width: 22)
            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

//#Preview {
//    let m = StaffRegistrationModel()
//    m.firstName    = "Jane"
//    m.lastName     = "Smith"
//    m.email        = "jane@company.com"
//    m.selectedRole = .maintenance
//    m.accountCreated = true
//    return AddStaffSuccessView(model: m, onDone: {})
//}
