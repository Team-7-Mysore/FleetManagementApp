import SwiftUI

struct EditVehicleView: View {
    @ObservedObject var vm: VehicleDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftVehicle: Vehicle?
    @State private var isSaving = false
    @State private var showSourcePicker = false
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @State private var selectedUploadType = "VEHICLE"

    var body: some View {
        Group {
            if let vehicle = draftVehicle ?? vm.vehicle {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        imageSection(vehicle)
                        basicInfoSection
                        documentsSection

                        Button {
                            Task {
                                await saveChanges()
                            }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color.TechBlue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .disabled(isSaving)
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Edit Vehicle")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .confirmationDialog("Select Source", isPresented: $showSourcePicker) {
                    if selectedUploadType == "VEHICLE" {
                        Button("Choose Photo") {
                            showImagePicker = true
                        }
                    } else {
                        Button("Choose File") {
                            showDocumentPicker = true
                        }
                        Button("Choose Photo") {
                            showImagePicker = true
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                }
                .sheet(isPresented: $showDocumentPicker) {
                    DocumentPicker { url in
                        Task {
                            await vm.uploadDocument(fileURL: url, type: selectedUploadType)
                        }
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker { image in
                        Task {
                            await vm.uploadImage(image: image, type: selectedUploadType)
                            if selectedUploadType == "VEHICLE" {
                                draftVehicle?.imageURL = vm.vehicle?.imageURL
                            }
                        }
                    }
                }
                .alert(
                    "Update Failed",
                    isPresented: Binding(
                        get: { vm.errorMessage != nil },
                        set: { if !$0 { vm.errorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(vm.errorMessage ?? "")
                }
                .onAppear {
                    draftVehicle = vm.vehicle
                }
            } else {
                ProgressView()
                    .navigationTitle("Edit Vehicle")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private func imageSection(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vehicle Image")
                .font(.headline)

            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let urlString = vehicle.imageURL,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            imagePlaceholder
                        }
                    } else {
                        imagePlaceholder
                    }
                }
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button {
                    selectedUploadType = "VEHICLE"
                    showSourcePicker = true
                } label: {
                    Label("Change", systemImage: "camera.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.TechBlue)
                        .clipShape(Capsule())
                }
                .padding(16)
            }
        }
    }

    private var imagePlaceholder: some View {
        VehicleFallbackArtwork(vehicleType: draftVehicle?.vehicleType ?? vm.vehicle?.vehicleType)
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Basic Information")
                .font(.headline)

            VStack(spacing: 14) {
                editorField(title: "Vehicle Name", text: binding(\.name))
                editorField(title: "Registration Number", text: binding(\.registrationNumber), autocapitalized: true)
                editorField(title: "Brand", text: binding(\.brand))
                editorField(title: "Vehicle Type", text: binding(\.vehicleType))
                editorField(title: "Fuel Type", text: binding(\.fuelType))
                editorField(title: "Model", text: binding(\.model))
                editorField(title: "Model Year", text: binding(\.modelYear))
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Documents")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(documentTypes, id: \.self) { documentType in
                    EditableDocumentRow(
                        title: documentTitle(for: documentType),
                        fileURL: vm.document(for: documentType)?.fileURL,
                        actionTitle: vm.document(for: documentType) == nil ? "Upload" : "Replace"
                    ) {
                        selectedUploadType = documentType
                        showSourcePicker = true
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func editorField(
        title: String,
        text: Binding<String>,
        autocapitalized: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(autocapitalized ? .characters : .words)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Vehicle, String>) -> Binding<String> {
        Binding(
            get: { draftVehicle?[keyPath: keyPath] ?? vm.vehicle?[keyPath: keyPath] ?? "" },
            set: {
                if draftVehicle == nil {
                    draftVehicle = vm.vehicle
                }
                draftVehicle?[keyPath: keyPath] = $0
            }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<Vehicle, String?>) -> Binding<String> {
        Binding(
            get: { draftVehicle?[keyPath: keyPath] ?? vm.vehicle?[keyPath: keyPath] ?? "" },
            set: {
                if draftVehicle == nil {
                    draftVehicle = vm.vehicle
                }
                draftVehicle?[keyPath: keyPath] = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
            }
        )
    }

    private func saveChanges() async {
        guard let draftVehicle else { return }
        isSaving = true
        vm.vehicle = draftVehicle
        let didSave = await vm.updateVehicle()
        isSaving = false
        if didSave {
            dismiss()
        }
    }

    private var documentTypes: [String] {
        ["RC", "INSURANCE", "PUC"]
    }

    private func documentTitle(for type: String) -> String {
        switch type {
        case "RC":
            return "RC"
        case "INSURANCE":
            return "Insurance"
        case "PUC":
            return "PUC"
        default:
            return type.capitalized
        }
    }
}

struct EditableDocumentRow: View {
    let title: String
    let fileURL: String?
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(fileURL?.isEmpty == false ? "Uploaded" : "Not uploaded")
                    .font(.caption)
                    .foregroundColor(fileURL?.isEmpty == false ? .green : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(actionTitle, action: action)
                .font(.caption.weight(.semibold))
                .foregroundColor(.TechBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
