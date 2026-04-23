import Foundation
import SwiftUI

struct LoginView: View {
    @State private var isPasswordVisible = false
    @ObservedObject var viewModel: AuthViewModel

    private var canSubmit: Bool {
        switch viewModel.signInStage {
        case .credentials:
            return !viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.password.isEmpty &&
            !viewModel.isSigningIn
        case .otp:
            return !viewModel.otpCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.isVerifyingOTP
        }
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
                    if viewModel.signInStage == .credentials {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)

                            ZStack(alignment: .leading) {
                                if viewModel.email.isEmpty {
                                    Text("Enter your email")
                                        .foregroundStyle(.gray)
                                        .padding(.horizontal, 16)
                                }

                                TextField("", text: $viewModel.email)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 16)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.emailAddress)
                            }
                            .frame(height: 54)
                            .background(Color(red: 0.93, green: 0.94, blue: 0.97))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Password")
                                    .font(.headline)

                                Spacer()

                                Button("Forgot Password?") {
                                }
                                .font(.subheadline.weight(.semibold))
                            }

                            HStack(spacing: 10) {
                                ZStack(alignment: .leading) {
                                    if viewModel.password.isEmpty {
                                        Text("Password")
                                            .foregroundStyle(Color(.systemGray).opacity(0.7))
                                    }

                                    if isPasswordVisible {
                                        TextField("", text: $viewModel.password)
                                            .foregroundStyle(.primary)
                                    } else {
                                        SecureField("", text: $viewModel.password)
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
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enter OTP")
                                .font(.headline)

                            ZStack(alignment: .leading) {
                                if viewModel.otpCode.isEmpty {
                                    Text("6-digit code")
                                        .foregroundStyle(.gray)
                                        .padding(.horizontal, 16)
                                }

                                TextField("", text: $viewModel.otpCode)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 16)
                                    .keyboardType(.numberPad)
                            }
                            .frame(height: 54)
                            .background(Color(red: 0.93, green: 0.94, blue: 0.97))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            HStack {
                                Button("Resend OTP") {
                                    Task { await viewModel.sendOTP() }
                                }
                                .font(.subheadline.weight(.semibold))
                                .disabled(viewModel.isSendingOTP)

                                Spacer()

                                Button("Cancel") {
                                    Task { await viewModel.resetOTPFlow() }
                                }
                                .font(.subheadline.weight(.semibold))
                            }
                        }
                    }

                    Button {
                        Task {
                            if viewModel.signInStage == .credentials {
                                await viewModel.signIn()
                            } else {
                                await viewModel.verifyOTP()
                            }
                        }
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

                            if viewModel.isSigningIn || viewModel.isVerifyingOTP {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(viewModel.signInStage == .credentials ? "Log In" : "Verify OTP")
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

                    if let infoMessage = viewModel.infoMessage {
                        Text(infoMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        let appSession = AppSession()
        LoginView(viewModel: AuthViewModel(appSession: appSession))
    }
}
