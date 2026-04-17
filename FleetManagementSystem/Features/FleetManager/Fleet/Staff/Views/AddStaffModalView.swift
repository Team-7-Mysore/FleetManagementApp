
//
//  AddStaffModalView.swift
//  FleetManagementSystem
//
//  Step 1 of 2 — Enter basic details + role  (Form style matches CreateTripView)
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
        Form {

            // MARK: Personal Details
            Section(header: Text("Personal Details")) {

                TextField("First Name", text: $firstNameText)
                    .autocapitalization(.words)
                    .onChange(of: firstNameText) { _ in syncToModel() }

                TextField("Last Name", text: $lastNameText)
                    .autocapitalization(.words)
                    .onChange(of: lastNameText) { _ in syncToModel() }

                TextField("Email Address", text: $emailText)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: emailText) { _ in syncToModel() }

                TextField("Phone Number (Optional)", text: $phoneText)
                    .keyboardType(.phonePad)
                    .onChange(of: phoneText) { _ in syncToModel() }
            }

            // MARK: Auto-generated Username
            Section(header: Text("Username"), footer: Text("Username is auto-generated from the name you enter.")) {
                HStack(spacing: 12) {
                    Image(systemName: "at")
                        .foregroundStyle(.secondary)

                    Text(model.generatedUsername.isEmpty
                         ? "Fill in your name above"
                         : model.displayUsername)
                        .foregroundStyle(model.generatedUsername.isEmpty ? .secondary : .primary)

                    Spacer()

                    if !model.generatedUsername.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }

            // MARK: Role
            Section(header: Text("Role")) {
                Picker("Staff Role", selection: $model.selectedRole) {
                    Text("Select Role").tag(StaffRole?.none)
                    ForEach(StaffRole.allCases) { role in
                        Text(role.rawValue).tag(Optional(role))
                    }
                }

                if let role = model.selectedRole {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 1)
                        Text(role.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Add Person")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") {
                    syncToModel()
                    onNext()
                }
                .disabled(!model.isFormValid)
            }
        }
        .onAppear {
            firstNameText = model.firstName
            lastNameText  = model.lastName
            emailText     = model.email
            phoneText     = model.phoneNo
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
