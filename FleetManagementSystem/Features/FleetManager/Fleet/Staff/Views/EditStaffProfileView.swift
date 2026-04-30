//
//  EditStaffProfileView.swift
//  FleetManagementSystem
//

import SwiftUI
import Supabase

struct EditStaffProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Binding to the staff user so changes reflect in profile view
    @Binding var staff: StaffUser
    
    // Optional driver details passed from StaffProfileView
    var initialLicenseNumber: String?
    var initialLicenseExpiry: String?
    var initialLicenseImageURL: String?
    var onSaveDriverDetails: ((String, String, String?) -> Void)?
    
    // Local state for editing
    @State private var firstNameText: String = ""
    @State private var lastNameText: String = ""
    @State private var phoneText: String = ""
    @State private var licenseNumberText: String = ""
    @State private var licenseExpiryText: String = ""
    
    @State private var newLicenceImage: UIImage? = nil
    @State private var showLicenceSourcePicker: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var showCameraPicker: Bool = false
    @State private var showFullImage: Bool = false
    
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Account Details").foregroundColor(.primary)) {
                    LabeledContent("Email", value: staff.email)
                    LabeledContent("Role", value: staff.role.displayName)
                }
                
                Section(header: Text("Personal Details").foregroundColor(.primary)) {
                    TextField("First Name", text: $firstNameText)
                        .autocapitalization(.words)
                        
                    TextField("Last Name", text: $lastNameText)
                        .autocapitalization(.words)
                    
                    TextField("Phone Number", text: $phoneText)
                        .keyboardType(.phonePad)
                }
                
                if staff.role == .driver {
                    if let image = newLicenceImage {
                        // New Image Uploaded
                        Section(header: Text("Driver's Licence").foregroundColor(.primary), footer: Text("Make sure the licence is clearly visible and not blurry.")) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.badge.checkmark")
                                    .font(.title2)
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("New Document Uploaded")
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
                                        showLicenceSourcePicker = true
                                    } label: {
                                        Label("Re-upload", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                    Button(role: .destructive) {
                                        newLicenceImage = nil
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
                    } else if let imageUrl = initialLicenseImageURL, !imageUrl.isEmpty {
                        // Existing Image
                        Section(header: Text("Driver's Licence").foregroundColor(.primary), footer: Text("Make sure the licence is clearly visible and not blurry.")) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo.badge.checkmark")
                                    .font(.title2)
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Document Uploaded")
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text("Existing Image")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()

                                Button("View") {
                                    showFullImage = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Menu {
                                    Button {
                                        showLicenceSourcePicker = true
                                    } label: {
                                        Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .imageScale(.large)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } else {
                        // Not yet uploaded state
                        Section(header: Text("Driver's Licence").foregroundColor(.primary),
                                footer: Text("A licence image is required for drivers.")) {
                            Button {
                                showLicenceSourcePicker = true
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
                    
                    Section(header: Text("License Details").foregroundColor(.primary)) {
                        TextField("License Number", text: $licenseNumberText)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
                            
                        TextField("Expiry Date (e.g. DD/MM/YYYY)", text: $licenseExpiryText)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveProfile() }
                    }
                    .disabled(isSaving || firstNameText.trimmingCharacters(in: .whitespaces).isEmpty || lastNameText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Upload Licence", isPresented: $showLicenceSourcePicker) {
                Button("Take Photo from Camera") {
                    showCameraPicker = true
                }
                Button("Take Photo from Gallery") {
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Choose how you'd like to upload the licence image.")
            }
            .sheet(isPresented: $showImagePicker) {
                LicenceImagePicker(selectedImage: $newLicenceImage)
            }
            .sheet(isPresented: $showCameraPicker) {
                LicenceCameraPicker(selectedImage: $newLicenceImage)
            }
            .sheet(isPresented: $showFullImage) {
                NavigationStack {
                    ZStack {
                        Color(.systemGroupedBackground).ignoresSafeArea()
                        if let image = newLicenceImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        } else if let imageUrl = initialLicenseImageURL, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let img):
                                    img.resizable().scaledToFit().padding()
                                case .failure:
                                    Text("Failed to load image")
                                        .foregroundColor(.red)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
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
            .onAppear {
                let parts = staff.name.split(separator: " ")
                if parts.count > 1 {
                    firstNameText = String(parts.first!)
                    lastNameText = parts.dropFirst().joined(separator: " ")
                } else {
                    firstNameText = staff.name
                    lastNameText = ""
                }
                phoneText = staff.phone_no ?? ""
                licenseNumberText = initialLicenseNumber ?? ""
                licenseExpiryText = initialLicenseExpiry ?? ""
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    private func saveProfile() async {
        isSaving = true
        errorMessage = nil
        
        let updatedName = "\(firstNameText) \(lastNameText)".trimmingCharacters(in: .whitespaces)
        let updatedPhone = phoneText.trimmingCharacters(in: .whitespaces)
        
        do {
            // Update user details
            try await SupabaseManager.shared.client
                .from("users")
                .update([
                    "name": updatedName,
                    "phone_no": updatedPhone.isEmpty ? nil : updatedPhone
                ])
                .eq("user_id", value: staff.user_id)
                .execute()
                
            // Update driver details if applicable
            var newLicenseNo: String? = nil
            var newLicenseExpiry: String? = nil
            var newImageUrl: String? = nil
            
            if staff.role == .driver {
                let cleanLicenseNo = licenseNumberText.trimmingCharacters(in: .whitespaces)
                
                // Parse date
                guard let dbDate = parsedExpiryDateForDB(licenseExpiryText) else {
                    await MainActor.run {
                        errorMessage = "Invalid licence expiry date"
                        isSaving = false
                    }
                    return
                }
                
                // Upload new image if selected
                if let image = newLicenceImage {
                    if let url = try await uploadLicenceImage(image) {
                        newImageUrl = url
                    } else {
                        await MainActor.run {
                            errorMessage = "Failed to upload licence image"
                            isSaving = false
                        }
                        return
                    }
                }
                
                var driverUpdates: [String: String] = [
                    "license_no": cleanLicenseNo,
                    "license_expiry": dbDate
                ]
                
                if let url = newImageUrl {
                    driverUpdates["license_image_url"] = url
                }
                
                try await SupabaseManager.shared.client
                    .from("drivers")
                    .update(driverUpdates)
                    .eq("user_id", value: staff.user_id)
                    .execute()
                
                newLicenseNo = cleanLicenseNo
                newLicenseExpiry = dbDate
            }
            
            // Update local state
            await MainActor.run {
                staff.name = updatedName
                staff.phone_no = updatedPhone.isEmpty ? nil : updatedPhone
                if let ln = newLicenseNo, let le = newLicenseExpiry {
                    onSaveDriverDetails?(ln, le, newImageUrl ?? initialLicenseImageURL)
                }
                isSaving = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
    
    // Helper to format date for DB
    private func parsedExpiryDateForDB(_ dateString: String) -> String? {
        let formatter = DateFormatter()
        let formats = [
            "dd/MM/yyyy", "dd-MM-yyyy",
            "MM/dd/yyyy", "MM-dd-yyyy",
            "dd/MM/yy", "yyyy-MM-dd"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: date)
            }
        }
        return nil
    }
    
    private func uploadLicenceImage(_ image: UIImage) async throws -> String? {
        guard let data = image.jpegData(compressionQuality: 0.5) else {
            return nil
        }

        let fileName = "licence_\(UUID().uuidString).jpg"
        let bucket = "staff-licences"

        try await SupabaseManager.shared.client.storage
            .from(bucket)
            .upload(
                path: fileName,
                file: data,
                options: FileOptions(contentType: "image/jpeg")
            )

        return "\(SupabaseConfig.url)/storage/v1/object/public/\(bucket)/\(fileName)"
    }
}
