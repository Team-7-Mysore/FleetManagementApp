
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

            // MARK: Licence Upload (Driver only)
            if model.selectedRole == .driver {
                if let image = model.licenceImage {
                    // Uploaded state — compact row
                    Section(header: Text("Driver's Licence"), footer: Text("Make sure the licence is clearly visible and not blurry.")) {
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

                    Section(header: Text("Licence Details")) {
                        TextField("Licence Number", text: $model.licenceNumber)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                        
                        TextField("Expiry Date (e.g. DD/MM/YYYY)", text: $model.licenceExpiryDate)
                            .keyboardType(.numbersAndPunctuation)
                    }

                } else {
                    // Not yet uploaded state
                    Section(header: Text("Driver's Licence"),
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
