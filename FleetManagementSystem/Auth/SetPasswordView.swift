//
//  SetPasswordView.swift
//  FleetManagementSystem
//
//  Created by Apple on 16/04/26.
//

import SwiftUI
import Supabase

struct SetPasswordView: View {
    let onPasswordSet: () -> Void

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var minimumLengthMet: Bool {
        password.count >= 8
    }

    private var hasUppercase: Bool {
        password.range(of: "[A-Z]", options: .regularExpression) != nil
    }

    private var hasLowercase: Bool {
        password.range(of: "[a-z]", options: .regularExpression) != nil
    }

    private var hasNumber: Bool {
        password.range(of: "[0-9]", options: .regularExpression) != nil
    }

    private var hasSpecialCharacter: Bool {
        password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil
    }

    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }

    private var allRequirementsMet: Bool {
        minimumLengthMet && hasUppercase && hasLowercase && hasNumber && hasSpecialCharacter
    }

    private var canSubmit: Bool {
        !isLoading && allRequirementsMet && passwordsMatch
    }

    private var strengthLabel: String {
        let score = [minimumLengthMet, hasUppercase, hasLowercase, hasNumber, hasSpecialCharacter].filter { $0 }.count

        switch score {
        case 0...2: return "Weak"
        case 3...4: return "Fair"
        default: return "Strong"
        }
    }

    private var strengthColor: Color {
        switch strengthLabel {
        case "Weak":
            return AppTheme.statusDanger
        case "Fair":
            return AppTheme.statusWarning
        default:
            return primaryBlue
        }
    }

    private var primaryBlue: Color {
        Color(red: 0.14, green: 0.42, blue: 0.92)
    }

    private var darkBlue: Color {
        Color(red: 0.08, green: 0.25, blue: 0.70)
    }

    private var lightBlue: Color {
        Color(red: 0.90, green: 0.94, blue: 1.00)
    }

    private var paleBlue: Color {
        Color(red: 0.82, green: 0.90, blue: 1.00)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [lightBlue, Color.white, paleBlue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    iconHeader

                    VStack(alignment: .leading, spacing: 16) {
                        titleSection
                        passwordFields
                        requirementsSection
                        submitButton

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppTheme.statusDanger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                        }
                    }
                    .padding(22)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(primaryBlue.opacity(0.25), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .animation(.snappy(duration: 0.25), value: errorMessage)
    }

    private var iconHeader: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [primaryBlue, darkBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 96, height: 96)
            .overlay {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: primaryBlue.opacity(0.24), radius: 14, x: 0, y: 8)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Create Your Password")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text("Use a strong password to secure your fleet account.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var passwordFields: some View {
        VStack(spacing: 12) {
            passwordField(
                title: "Password",
                placeholder: "Enter new password",
                text: $password,
                isVisible: $isPasswordVisible
            )

            passwordField(
                title: "Confirm Password",
                placeholder: "Re-enter password",
                text: $confirmPassword,
                isVisible: $isConfirmPasswordVisible
            )
        }
    }

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Password Strength")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(strengthLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(strengthColor)
            }

            requirementRow("At least 8 characters", isMet: minimumLengthMet)
            requirementRow("At least 1 uppercase letter", isMet: hasUppercase)
            requirementRow("At least 1 lowercase letter", isMet: hasLowercase)
            requirementRow("At least 1 number", isMet: hasNumber)
            requirementRow("At least 1 special character", isMet: hasSpecialCharacter)
            requirementRow("Passwords match", isMet: passwordsMatch)
        }
        .padding(14)
        .background(lightBlue.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }

    private var submitButton: some View {
        Button(isLoading ? "Saving..." : "Save Password") {
            setPassword()
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [primaryBlue, darkBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.65)
        .overlay {
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private func passwordField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            HStack(spacing: 10) {
                Group {
                    if isVisible.wrappedValue {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(isLoading)

                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        }
    }

    private func requirementRow(_ title: String, isMet: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isMet ? primaryBlue : .secondary)

            Text(title)
                .font(.footnote)
                .foregroundStyle(.primary)
        }
    }

    private func setPassword() {
        guard canSubmit else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(password: password)
                )

                print("✅ Password set successfully")

                await MainActor.run {
                    isLoading = false
                    onPasswordSet()
                }

            } catch {
                print("❌ Error setting password:", error)
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Could not set password right now. Please try again."
                }
            }
        }
    }
}
