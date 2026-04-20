import SwiftUI

struct LoginView: View {
    @State private var emailOrUsername = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isSigningIn = false

    private var canSubmit: Bool {
        !emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        !isSigningIn
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, Color(red: 0.95, green: 0.96, blue: 0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 24)

                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 104, height: 104)
                        .overlay {
                            Image(systemName: "truck.box.fill")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .blue.opacity(0.22), radius: 18, x: 0, y: 10)

                    VStack(spacing: 6) {
                        Text("The FMS")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text("Streamlining Every Mile")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email or Username")
                            .font(.headline)

                        ZStack(alignment: .leading) {
                            if emailOrUsername.isEmpty {
                                Text("john.doe@precision.com")
                                    .foregroundStyle(Color(.systemGray).opacity(0.7))
                                    .padding(.horizontal, 16)
                            }

                            TextField("", text: $emailOrUsername)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 16)
                        }
                        .frame(height: 54)
                        .background(Color(red: 0.93, green: 0.94, blue: 0.97))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("PASSWORD")
                                .font(.footnote.weight(.semibold))
                                .tracking(1)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button("Forgot Password?") {
                            }
                            .font(.subheadline.weight(.semibold))
                        }

                        HStack(spacing: 10) {
                            ZStack(alignment: .leading) {
                                if password.isEmpty {
                                    Text("Password")
                                        .foregroundStyle(Color(.systemGray).opacity(0.7))
                                }

                                if isPasswordVisible {
                                    TextField("", text: $password)
                                        .foregroundStyle(.primary)
                                } else {
                                    SecureField("", text: $password)
                                        .foregroundStyle(.primary)
                                }
                            }

                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 26, height: 26)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(Color(red: 0.93, green: 0.94, blue: 0.97))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button {
                        Task { await signIn() }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            if isSigningIn {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Log In")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(height: 58)
                        .shadow(color: .blue.opacity(0.22), radius: 16, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.65)
                }
                .padding(20)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                Spacer(minLength: 24)

                Text("VERSION 1.0.0")
                    .font(.footnote.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func signIn() async {
        isSigningIn = true
        defer { isSigningIn = false }
        try? await Task.sleep(for: .milliseconds(700))
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
