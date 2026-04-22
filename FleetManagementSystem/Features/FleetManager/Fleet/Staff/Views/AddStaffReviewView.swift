
//
//  AddStaffReviewView.swift
//  FleetManagementSystem
//
//  Step 2 of 2 — Review details before creating account (Form style matches AddStaffModalView)
//

import SwiftUI

struct AddStaffReviewView: View {

    @ObservedObject var model: StaffRegistrationModel
    let onBack:   () -> Void
    let onSubmit: () -> Void

    var body: some View {
        Form {
            // MARK: Profile Header
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.12))
                            .frame(width: 60, height: 60)
                        
                        Text(initials)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(model.firstName) \(model.lastName)")
                            .font(.headline)
                        
                        if let role = model.selectedRole {
                            Text(role.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // MARK: Details
            Section(header: Text("Staff Details")) {
                LabeledContent("Email", value: model.email)
                LabeledContent("Phone", value: model.phoneNo.isEmpty ? "—" : model.phoneNo)
                LabeledContent("Role", value: model.selectedRole?.rawValue ?? "—")
            }

            if model.selectedRole == .driver {
                Section(header: Text("Licence Details")) {
                    LabeledContent("Licence Number", value: model.licenceNumber.isEmpty ? "—" : model.licenceNumber)
                    LabeledContent("Expiry Date", value: model.licenceExpiryDate.isEmpty ? "—" : model.licenceExpiryDate)
                }
            }

            // MARK: Account Info
            Section(header: Text("Account Creation"), footer: Text("Login details will be sent to \(model.email.isEmpty ? "the user" : model.email) after creation.")) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .foregroundStyle(.blue)
                    Text("Credentials will be sent via email")
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: onSubmit) {
                    if model.isCreatingAccount {
                        ProgressView()
                    } else {
                        Text("Confirm")
                    }
                }
                .disabled(model.isCreatingAccount)
            }
        }
        .alert("Account Creation Failed", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var initials: String {
        let f = model.firstName.first.map(String.init) ?? ""
        let l = model.lastName.first.map(String.init) ?? ""
        return (f + l).uppercased()
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
