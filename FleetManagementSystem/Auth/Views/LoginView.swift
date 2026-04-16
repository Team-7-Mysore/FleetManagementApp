import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var sessionStore: AppSessionStore
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        ZStack {
            DriverTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer(minLength: 24)

                    header
                    loginCard
                    demoCredentials

                    Text("Fleet access is role-based. Drivers land in the driver interface automatically after login.")
                        .font(.footnote)
                        .foregroundStyle(DriverTheme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(DriverTheme.cardBackground)
                .frame(width: 108, height: 108)
                .overlay {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(DriverTheme.accent)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(DriverTheme.cardStroke, lineWidth: 1)
                )

            VStack(spacing: 8) {
                Text("Fleet Management")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Secure login for drivers, fleet managers, and maintenance teams.")
                    .font(.body)
                    .foregroundStyle(DriverTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 28)
    }

    private var loginCard: some View {
        VStack(spacing: 18) {
            credentialField(
                title: "Email or Username",
                placeholder: "driver@fms.com",
                text: $viewModel.emailOrUsername,
                keyboardType: .emailAddress,
                textContentType: .username
            )

            passwordField

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await handleSignIn() }
            } label: {
                ZStack {
                    if viewModel.isSigningIn {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Log In")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!viewModel.canSubmit)
            .opacity(viewModel.canSubmit ? 1 : 0.62)
        }
        .padding(22)
        .background(DriverTheme.cardBackground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(DriverTheme.cardStroke, lineWidth: 1)
        )
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Password")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button("Forgot Password?") { }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DriverTheme.accent)
            }

            HStack(spacing: 12) {
                Group {
                    if viewModel.isPasswordVisible {
                        TextField("", text: $viewModel.password)
                            .textContentType(.password)
                    } else {
                        SecureField("", text: $viewModel.password)
                            .textContentType(.password)
                    }
                }
                .foregroundStyle(.white)

                Button {
                    viewModel.isPasswordVisible.toggle()
                } label: {
                    Image(systemName: viewModel.isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(DriverTheme.secondaryText)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
            .modifier(LoginFieldContainer(placeholder: "Enter your password", textIsEmpty: viewModel.password.isEmpty))
        }
    }

    private var demoCredentials: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Demo Driver Credentials")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Email: `driver@fms.com`\nPassword: `Driver@123`")
                .font(.subheadline)
                .foregroundStyle(DriverTheme.secondaryText)

            Text("Until the fleet manager admin flow is built, these seeded credentials let you test the driver route directly.")
                .font(.footnote)
                .foregroundStyle(DriverTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(DriverTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DriverTheme.cardStroke, lineWidth: 1)
        )
    }

    private func credentialField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        textContentType: UITextContentType?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            TextField("", text: text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(textContentType)
                .foregroundStyle(.white)
                .modifier(LoginFieldContainer(placeholder: placeholder, textIsEmpty: text.wrappedValue.isEmpty))
        }
    }

    private func handleSignIn() async {
        do {
            let session = try await viewModel.signIn()
            sessionStore.signIn(session: session)
        } catch {
        }
    }
}

private struct LoginFieldContainer: ViewModifier {
    let placeholder: String
    let textIsEmpty: Bool

    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            if textIsEmpty {
                Text(placeholder)
                    .foregroundStyle(DriverTheme.tertiaryText)
                    .padding(.horizontal, 16)
            }

            content
                .padding(.horizontal, 16)
        }
        .frame(height: 54)
        .background(DriverTheme.fieldBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DriverTheme.cardStroke, lineWidth: 1)
        )
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AppSessionStore())
    }
}
