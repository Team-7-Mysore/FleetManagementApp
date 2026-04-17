import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var router: AppRouter

    @State private var email = "john.carter@fms.com"
    @State private var password = "xxx"
    @State private var isPasswordVisible = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        !router.isLoading
    }

    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 48)

                    // MARK: - Logo & Title
                    VStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.primaryGreen, AppTheme.darkGreen],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay {
                                Image(systemName: "truck.box.fill")
                                    .font(.system(size: 38, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: AppTheme.primaryGreen.opacity(0.15), radius: 8, x: 0, y: 4)

                        VStack(spacing: 6) {
                            Text("The FMS")
                                .font(.largeTitle.weight(.bold))

                            Text("Streamlining Every Mile")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 8)

                    // MARK: - Login Form
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EMAIL")
                                .font(.caption.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 12) {
                                Image(systemName: "envelope")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)

                                TextField("john.carter@fms.com", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous))
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PASSWORD")
                                .font(.caption.weight(.semibold))
                                .tracking(0.8)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 12) {
                                Image(systemName: "lock")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)

                                if isPasswordVisible {
                                    TextField("Password", text: $password)
                                        .textContentType(.password)
                                } else {
                                    SecureField("Password", text: $password)
                                        .textContentType(.password)
                                }

                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous))
                        }

                        // Error Message
                        if let error = router.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppTheme.statusDanger)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.statusDanger)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.statusDanger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        // Login Button
                        Button {
                            Task { await router.signIn(email: email, password: password) }
                        } label: {
                            HStack(spacing: 8) {
                                if router.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Log In")
                                }
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.6)
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                    .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)

                    // MARK: - Demo Hint
                    VStack(spacing: 6) {
                        Text("Demo Credentials")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Driver: john.carter@fms.com")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Any password works")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

