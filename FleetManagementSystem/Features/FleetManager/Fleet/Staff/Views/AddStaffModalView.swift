
//
//  AddStaffModalView.swift
//  FleetManagementSystem
//
//  Step 1 of 2 — Enter basic details + role
//

import SwiftUI

struct AddStaffModalView: View {

    @ObservedObject var model: StaffRegistrationModel
    let onDismiss: () -> Void
    let onNext:    () -> Void

    @State private var firstNameText: String = ""
    @State private var lastNameText:  String = ""
    @State private var emailText:     String = ""
    @State private var phoneText:     String = ""

    private func syncToModel() {
        model.firstName = firstNameText
        model.lastName  = lastNameText
        model.email     = emailText
        model.phoneNo   = phoneText
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {

                // MARK: Step indicator
                StepProgressBar(currentStep: 1, totalSteps: 2)
                    .padding(.horizontal)
                    .padding(.top, 4)

                // MARK: Personal Details
                SectionCard(title: "Personal Details", icon: "person.crop.rectangle") {

                    HStack(spacing: 12) {
                        StyledField(title: "FIRST NAME", placeholder: "John", text: $firstNameText)
                            .onChange(of: firstNameText) { _ in syncToModel() }

                        StyledField(title: "LAST NAME", placeholder: "Doe", text: $lastNameText)
                            .onChange(of: lastNameText) { _ in syncToModel() }
                    }

                    StyledField(
                        title: "EMAIL ADDRESS",
                        placeholder: "john@company.com",
                        text: $emailText,
                        keyboardType: .emailAddress
                    )
                    .onChange(of: emailText) { _ in syncToModel() }

                    StyledField(
                        title: "PHONE NUMBER (OPTIONAL)",
                        placeholder: "98XXXXXXXX",
                        text: $phoneText,
                        keyboardType: .phonePad
                    )
                    .onChange(of: phoneText) { _ in syncToModel() }

                    // Auto username row
                    VStack(alignment: .leading, spacing: 6) {
                        Text("USERNAME (AUTO-GENERATED)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .tracking(0.4)

                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.primaryBrown.opacity(0.1))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "at")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.primaryBrown)
                            }

                            Text(model.generatedUsername.isEmpty ? "Fill in your name above" : model.displayUsername)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(model.generatedUsername.isEmpty ? Color.gray.opacity(0.45) : .primary)

                            Spacer()

                            if !model.generatedUsername.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.primaryBrown)
                                    .font(.system(size: 15))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.primaryBrown.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.primaryBrown.opacity(model.generatedUsername.isEmpty ? 0.15 : 0.35), lineWidth: 1)
                                )
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: model.generatedUsername.isEmpty)
                    }
                }

                // MARK: Role
                SectionCard(title: "Role", icon: "briefcase.fill") {

                    Text("SELECT ROLE")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .tracking(0.4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Role chips
                    HStack(spacing: 12) {
                        ForEach(StaffRole.allCases) { role in
                            RoleChip(role: role, isSelected: model.selectedRole == role) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    model.selectedRole = role
                                }
                            }
                        }
                    }

                    // Description
                    if let role = model.selectedRole {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.primaryBrown.opacity(0.7))
                            Text(role.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primaryBrown.opacity(0.06))
                        .cornerRadius(10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // MARK: CTA
                Button {
                    syncToModel()
                    onNext()
                } label: {
                    HStack(spacing: 8) {
                        Text("Review Details")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(model.isFormValid ? Color.primaryBrown : Color.gray.opacity(0.35))
                    )
                }
                .disabled(!model.isFormValid)
                .padding(.horizontal)
                .padding(.bottom, 12)
                .animation(.easeInOut(duration: 0.2), value: model.isFormValid)
            }
        }
        .background(Color(.systemGray6))
        .navigationTitle("Add Person")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            firstNameText = model.firstName
            lastNameText  = model.lastName
            emailText     = model.email
            phoneText     = model.phoneNo
        }
    }
}

// MARK: - Step Progress Bar

private struct StepProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("STEP \(currentStep) OF \(totalSteps)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primaryBrown)
                Spacer()
                Text(currentStep == 1 ? "Basic Info" : "Review")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.primaryBrown)
                        .frame(width: geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: currentStep)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Section Card

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.primaryBrown)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
            }

            content
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }
}

// MARK: - Styled Text Field

private struct StyledField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .tracking(0.4)

            TextField(placeholder, text: $text)
                .focused($isFocused)
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                .disableAutocorrection(keyboardType == .emailAddress)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isFocused ? Color.white : Color(.systemGray6))
                        .shadow(color: isFocused ? Color.primaryBrown.opacity(0.15) : .clear, radius: 4, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isFocused ? Color.primaryBrown.opacity(0.55) : Color.gray.opacity(0.2), lineWidth: 1.2)
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
    }
}

// MARK: - Role Chip

private struct RoleChip: View {
    let role: StaffRole
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: role.icon)
                    .font(.system(size: 14))
                Text(role.rawValue)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : Color.primaryBrown)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.primaryBrown : Color.primaryBrown.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.primaryBrown.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    NavigationStack {
        AddStaffModalView(
            model: StaffRegistrationModel(),
            onDismiss: {},
            onNext: {}
        )
    }
}
