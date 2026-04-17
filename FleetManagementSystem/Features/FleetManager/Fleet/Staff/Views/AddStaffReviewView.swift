
//
//  AddStaffReviewView.swift
//  FleetManagementSystem
//
//  Step 2 of 2 — Review details before creating account
//

import SwiftUI

struct AddStaffReviewView: View {

    @ObservedObject var model: StaffRegistrationModel
    let onBack:   () -> Void
    let onSubmit: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // MARK: Step indicator
                VStack(spacing: 6) {
                    HStack {
                        Text("STEP 2 OF 2")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.primaryBrown)
                        Spacer()
                        Text("Review")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Capsule()
                        .fill(Color.primaryBrown)
                        .frame(height: 4)
                }
                .padding(.horizontal)
                .padding(.top, 4)

                // MARK: Avatar header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.primaryBrown.opacity(0.18), Color.primaryBrown.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)

                        Text(initials)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color.primaryBrown)
                    }
                    .shadow(color: Color.primaryBrown.opacity(0.15), radius: 8, x: 0, y: 4)

                    Text("\(model.firstName) \(model.lastName)")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    if let role = model.selectedRole {
                        Label(role.rawValue, systemImage: role.icon)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.primaryBrown)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.primaryBrown.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)

                // MARK: Summary card
                VStack(spacing: 0) {
                    DetailRow(icon: "at",        label: "Username", value: model.generatedUsername)
                    Divider().padding(.leading, 52)
                    DetailRow(icon: "envelope",  label: "Email",    value: model.email)
                    Divider().padding(.leading, 52)
                    DetailRow(icon: "briefcase", label: "Role",     value: model.selectedRole?.rawValue ?? "—")
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                .padding(.horizontal)

                // MARK: Credentials banner
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.primaryBrown.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "envelope.badge.shield.half.filled")
                            .font(.system(size: 16))
                            .foregroundColor(Color.primaryBrown)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Credentials email")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Login details will be sent to \(model.email.isEmpty ? "the user" : model.email) after creation.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.primaryBrown.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.primaryBrown.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal)

                // MARK: Confirm button
                Button(action: onSubmit) {
                    HStack(spacing: 10) {
                        if model.isCreatingAccount {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                            Text("Creating Account…")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17))
                            Text("Confirm & Create Account")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(model.isCreatingAccount ? Color.gray.opacity(0.4) : Color.primaryBrown)
                            .shadow(color: Color.primaryBrown.opacity(model.isCreatingAccount ? 0 : 0.35), radius: 8, x: 0, y: 4)
                    )
                    .animation(.easeInOut(duration: 0.2), value: model.isCreatingAccount)
                }
                .disabled(model.isCreatingAccount)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding(.top, 12)
        }
        .background(Color(.systemGray6))
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var initials: String {
        let f = model.firstName.first.map(String.init) ?? ""
        let l = model.lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon:  String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.primaryBrown.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.primaryBrown)
            }
            .padding(.leading, 14)

            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)

            Spacer()

            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 14)
    }
}

#Preview {
    let m = StaffRegistrationModel()
    m.firstName    = "John"
    m.lastName     = "Doe"
    m.email        = "john@company.com"
    m.selectedRole = .driver
    return NavigationStack {
        AddStaffReviewView(model: m, onBack: {}, onSubmit: {})
    }
}
