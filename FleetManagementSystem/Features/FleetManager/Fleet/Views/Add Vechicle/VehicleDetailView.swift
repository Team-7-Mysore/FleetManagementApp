import SwiftUI
import Combine

struct VehicleDetailView: View {
    let vehicleId: UUID
    
    @StateObject private var vm = VehicleDetailViewModel()
    
    @State private var isEditing = false
    @State private var draftVehicle: Vehicle?
    @State private var isSaving = false
    
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary

    var body: some View {
        ScrollView {
            if vm.isLoading {
                ProgressView()
                    .padding(.top, 60)
                
            } else if let vehicle = vm.vehicle {
                VStack(alignment: .leading, spacing: 22) {
                    
                    vehicleImage(vehicle)
                    vehicleHeader(vehicle)
                    infoSection(vehicle)
                    documentsSection
                    
                }
                .padding()
                
            } else if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 60)
            }
        }
        .onAppear {
            Task {
                await vm.fetchVehicle(vehicleId: vehicleId)
            }
        }
        .navigationTitle("Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isEditing = false
                        draftVehicle = nil
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(isSaving)
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        draftVehicle = vm.vehicle
                        isEditing = true
                    }
                    .fontWeight(.semibold)
                    .disabled(vm.vehicle == nil)
                }
            }
        }
        
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: sourceType) { image in
                Task {
                    await vm.uploadImage(image: image, type: "VEHICLE")
                    if let newURL = vm.vehicle?.imageURL {
                        draftVehicle?.imageURL = newURL
                    }
                }
            }
        }
    }

    private func saveChanges() async {
        guard let draft = draftVehicle else { return }
        isSaving = true
        vm.vehicle = draft
        let success = await vm.updateVehicle()
        isSaving = false
        if success {
            isEditing = false
            draftVehicle = nil
        }
    }

    // MARK: - IMAGE

    private func vehicleImage(_ vehicle: Vehicle) -> some View {
        Group {
            if let urlString = vehicle.imageURL,
               let url = URL(string: urlString) {
                
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            if isEditing {
                Button {
                    sourceType = .camera
                    showImagePicker = true
                } label: {
                    ZStack {
                        Color.black.opacity(0.3)
                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .font(.title)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    // MARK: - HEADER
    
    private func vehicleHeader(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                TextField("Vehicle Name", text: binding(\.name))
                    .font(.title.bold())
                    .textFieldStyle(.plain)

                TextField("Registration Number", text: binding(\.registrationNumber))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .textFieldStyle(.plain)
            } else {
                Text(vehicle.name)
                    .font(.title.bold())

                Text(vehicle.registrationNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - INFO

    private func infoSection(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Info")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                InfoRow(title: "Brand", value: vehicle.brand ?? "—", isEditing: isEditing, text: binding(\.brand))
                InfoRow(title: "Model", value: vehicle.model ?? "—", isEditing: isEditing, text: binding(\.model))
                InfoRow(title: "Year", value: vehicle.modelYear ?? "—", isEditing: isEditing, text: binding(\.modelYear))
                InfoRow(title: "Fuel", value: vehicle.fuelType ?? "—", isEditing: isEditing, text: binding(\.fuelType))
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - DOCUMENTS

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Documents")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            VStack(spacing: 0) {

                if let documentsErrorMessage = vm.documentsErrorMessage {
                    Text(documentsErrorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else if vm.documents.isEmpty {
                    Text("No documents uploaded yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ForEach(vm.documents) { document in
                        if let url = URL(string: document.fileURL) {
                            Link(destination: url) {
                                DocumentRow(document: document)
                            }
                            .buttonStyle(.plain)
                        } else {
                            DocumentRow(document: document)
                        }
                    }
                }

            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Vehicle, String>) -> Binding<String> {
        Binding(
            get: { draftVehicle?[keyPath: keyPath] ?? "" },
            set: { draftVehicle?[keyPath: keyPath] = $0 }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<Vehicle, String?>) -> Binding<String> {
        Binding(
            get: { draftVehicle?[keyPath: keyPath] ?? "" },
            set: { draftVehicle?[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String
    var isEditing: Bool = false
    var text: Binding<String>? = nil

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            if isEditing, let text {
                TextField(title, text: text)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.body.weight(.medium))
            } else {
                Text(value)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let document: VehicleDocument

    var body: some View {
        HStack(spacing: 12) {
            if isImageDocument, let url = URL(string: document.fileURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    iconBadge
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                iconBadge
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(isImageDocument ? "Image Document" : "Open Document")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(document.statusText)
                .font(.caption.weight(.semibold))
                .foregroundColor(statusColor)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var isImageDocument: Bool {
        guard let url = URL(string: document.fileURL) else { return false }
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "webp", "heic"].contains(ext)
    }

    private var iconBadge: some View {
        Image(systemName: iconName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(iconColor)
            .frame(width: 30, height: 30)
            .background(iconColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var iconName: String {
        switch document.type.uppercased() {
        case "RC":
            return "doc.text.fill"
        case "INSURANCE":
            return "shield.lefthalf.filled"
        case "PUC":
            return "doc.badge.gearshape"
        default:
            return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch document.type.uppercased() {
        case "RC":
            return .green
        case "INSURANCE":
            return .orange
        case "PUC":
            return .red
        default:
            return .blue
        }
    }

    private var statusColor: Color {
        switch document.type.uppercased() {
        case "RC":
            return .green
        case "INSURANCE":
            return .orange
        case "PUC":
            return .red
        default:
            return .secondary
        }
    }
}
