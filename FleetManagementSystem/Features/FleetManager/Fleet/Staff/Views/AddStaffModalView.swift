//
//  AddStaffModalView.swift
//  FleetManagementSystem
//
//  Step 1 of 2 — Enter basic details + role  (Form style matches CreateTripView)
//

import SwiftUI
import PhotosUI
 
// MARK: - PHPicker wrapper

struct LicenceImagePicker: UIViewControllerRepresentable {

    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LicenceImagePicker
        init(_ parent: LicenceImagePicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    self.parent.selectedImage = object as? UIImage
                }
            }
        }
    }
}

// MARK: - Main View

struct AddStaffModalView: View {

    @ObservedObject var model: StaffRegistrationModel
    let onDismiss: () -> Void
    let onNext:    () -> Void

    @State private var firstNameText: String = ""
    @State private var lastNameText:  String = ""
    @State private var emailText:     String = ""
    @State private var phoneText:     String = ""
    @State private var showImagePicker: Bool = false
    @State private var showFullImage: Bool = false

    @State private var showValidationAlert: Bool = false
    @State private var validationMessage: String = ""

    private func syncToModel() {
        model.firstName = firstNameText
        model.lastName  = lastNameText
        model.email     = emailText
        model.phoneNo   = phoneText
    }
    
    private func validateFields() -> Bool {
        // Check for empty required fields
        if firstNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "First Name is required."
            return false
        }
        if lastNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "Last Name is required."
            return false
        }
        if emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "Email Address is required."
            return false
        }
        if phoneText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "Phone Number is required."
            return false
        }
        if model.selectedRole == nil {
            validationMessage = "Please select a Staff Role."
            return false
        }
        // Basic email format validation
        let email = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.contains("@") || !email.contains(".") {
            validationMessage = "Please enter a valid Email Address."
            return false
        }
        // Phone number validation: digits only, length exactly 10
        let phone = phoneText.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnly = phone.allSatisfy { $0.isWholeNumber }
        if !digitsOnly {
            validationMessage = "Phone Number should contain digits only."
            return false
        }
        if phone.count != 10 {
            validationMessage = "Phone Number must be exactly 10 digits."
            return false
        }
        if model.selectedRole == .driver {
            if model.licenceImage == nil {
                validationMessage = "Driver's licence image is required."
                return false
            }
            if model.licenceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationMessage = "Licence Number is required for drivers."
                return false
            }
            if model.licenceExpiryDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationMessage = "Licence Expiry Date is required for drivers."
                return false
            }
        }
        return true
    }

    var body: some View {
        Form {

            // MARK: Personal Details
            Section(header: Text("Personal Details").foregroundColor(.primary)) {

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

                TextField("Phone Number", text: $phoneText)
                    .keyboardType(.phonePad)
                    .onChange(of: phoneText) { _ in syncToModel() }
            }


            // MARK: Role
            Section(header: Text("Role").foregroundColor(.primary)) {
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

            // MARK: Licence Upload (Driver only)
            if model.selectedRole == .driver {
                if let image = model.licenceImage {
                    // Uploaded state — compact row
                    Section(header: Text("Driver's Licence").foregroundColor(.primary), footer: Text("Make sure the licence is clearly visible and not blurry.")) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.badge.checkmark")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Document Uploaded")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let data = image.jpegData(compressionQuality: 0.8) {
                                    let sizeKB = Double(data.count) / 1024.0
                                    let sizeString = sizeKB > 1024 ? String(format: "%.1f MB", sizeKB / 1024) : String(format: "%.0f KB", sizeKB)
                                    Text(sizeString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            
                            Button("View") {
                                showFullImage = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Menu {
                                Button {
                                    showImagePicker = true
                                } label: {
                                    Label("Re-upload", systemImage: "arrow.triangle.2.circlepath")
                                }
                                Button(role: .destructive) {
                                    model.licenceImage = nil
                                } label: {
                                    Label("Clear", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .imageScale(.large)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Section(header: Text("Licence Details").foregroundColor(.primary)) {
                        TextField("Licence Number", text: $model.licenceNumber)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                        
                        TextField("Expiry Date (e.g. DD/MM/YYYY)", text: $model.licenceExpiryDate)
                            .keyboardType(.numbersAndPunctuation)
                    }

                } else {
                    // Not yet uploaded state
                    Section(header: Text("Driver's Licence").foregroundColor(.primary),
                            footer: Text("A licence image is required for drivers.")) {
                        Button {
                            showImagePicker = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upload Licence")
                                        .foregroundStyle(.blue)
                                        .fontWeight(.medium)
                                    Text("Select an image from your gallery")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Person")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") {
                    if validateFields() {
                        syncToModel()
                        onNext()
                    } else {
                        showValidationAlert = true
                    }
                }
            }
        }
        .onAppear {
            firstNameText = model.firstName
            lastNameText  = model.lastName
            emailText     = model.email
            phoneText     = model.phoneNo
        }
        .sheet(isPresented: $showImagePicker) {
            LicenceImagePicker(selectedImage: $model.licenceImage)
        }
        .sheet(isPresented: $showFullImage) {
            if let image = model.licenceImage {
                NavigationStack {
                    ZStack {
                        Color(.systemGroupedBackground).ignoresSafeArea()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                    .navigationTitle("Licence Document")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showFullImage = false
                            }
                        }
                    }
                }
            }
        }
        .alert("Validation Error", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
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

