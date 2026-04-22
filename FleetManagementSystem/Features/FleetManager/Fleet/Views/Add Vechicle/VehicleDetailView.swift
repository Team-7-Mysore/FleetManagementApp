import SwiftUI
import Combine
import UniformTypeIdentifiers

struct VehicleDetailView: View {
    let vehicleId: UUID
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var vm = VehicleDetailViewModel()
    
    @State private var isEditing = false
    @State private var draftVehicle: Vehicle?
    @State private var isSaving = false
    
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    @State private var isImportingDocument = false
    @State private var activeDocumentType: String?
    
    // State for maintenance assignment via chat/notification
    @State private var showStaffSelection = false

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
                    
                    // Maintenance Section
                    maintenanceButton(vehicle)
                    
                }
                .padding()
                
            } else if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 60)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            Task {
                await vm.fetchVehicle(vehicleId: vehicleId)
            }
        }
        .navigationTitle("Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
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
        .sheet(isPresented: $showStaffSelection) {
            MaintenanceStaffPickerView(vehicle: vm.vehicle!)
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
        .fileImporter(
            isPresented: $isImportingDocument,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first, let type = activeDocumentType {
                    Task {
                        await vm.uploadDocument(fileURL: url, type: type)
                    }
                }
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveChanges() async {
        guard let draft = draftVehicle else { return }
        vm.vehicle = draft
        isEditing = false
        draftVehicle = nil
        isSaving = true
        let success = await vm.updateVehicle()
        if success {
            await vm.fetchVehicle(vehicleId: vehicleId)
        }
        isSaving = false
    }

    // MARK: - UI COMPONENTS
    
    private func vehicleImage(_ vehicle: Vehicle) -> some View {
        Group {
            if let urlString = vehicle.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
            } else {
                ZStack {
                    Color.gray.opacity(0.1)
                    Image(systemName: vehicle.imageSystemName)
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.4))
                }
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Documents")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                let requiredTypes = ["RC", "INSURANCE", "PUC"]
                ForEach(requiredTypes, id: \.self) { type in
                    let doc = vm.documents.first(where: { $0.type.uppercased() == type })
                    if isEditing {
                        Button {
                            activeDocumentType = type
                            isImportingDocument = true
                        } label: {
                            Group {
                                if let doc = doc { DocumentRow(document: doc, isEditing: true) }
                                else { missingDocumentRow(type: type) }
                            }
                        }
                        .buttonStyle(.plain)
                    } else if let doc = doc {
                        if let url = URL(string: doc.fileURL) {
                            Link(destination: url) { DocumentRow(document: doc) }.buttonStyle(.plain)
                        } else { DocumentRow(document: doc) }
                    } else { missingDocumentRow(type: type) }
                    
                    if type != requiredTypes.last && (isEditing || doc != nil) {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func maintenanceButton(_ vehicle: Vehicle) -> some View {
        Button {
            showStaffSelection = true
        } label: {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                    .frame(width: 40, height: 40)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notify Maintenance")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Assign technician via chat notification")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "person.badge.plus.fill")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func missingDocumentRow(type: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: type == "RC" ? "doc.text.fill" : (type == "INSURANCE" ? "shield.lefthalf.filled" : "doc.badge.gearshape"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(type).font(.subheadline.weight(.semibold))
                Text("Not uploaded").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if isEditing { Image(systemName: "plus.circle.fill").foregroundColor(.blue) }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func binding(_ keyPath: WritableKeyPath<Vehicle, String>) -> Binding<String> {
        Binding(get: { draftVehicle?[keyPath: keyPath] ?? "" }, set: { draftVehicle?[keyPath: keyPath] = $0 })
    }

    private func binding(_ keyPath: WritableKeyPath<Vehicle, String?>) -> Binding<String> {
        Binding(get: { draftVehicle?[keyPath: keyPath] ?? "" }, set: { draftVehicle?[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }
}

// MARK: - RE-ADDED MISSING COMPONENTS

struct InfoRow: View {
    let title: String
    let value: String
    var isEditing: Bool = false
    var text: Binding<String>? = nil

    var body: some View {
        HStack {
            Text(title).foregroundColor(.secondary)
            Spacer()
            if isEditing, let text {
                TextField(title, text: text)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.body.weight(.medium))
            } else {
                Text(value).fontWeight(.medium)
            }
        }
        .padding(.vertical, 6)
    }
}

struct DocumentRow: View {
    let document: VehicleDocument
    var isEditing: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if isImageDocument, let url = URL(string: document.fileURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    iconBadge
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                iconBadge
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title).font(.subheadline.weight(.semibold))
                Text(document.fileName ?? "Document").font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            if isEditing {
                Image(systemName: "pencil.circle.fill").foregroundColor(.blue)
            } else {
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private var isImageDocument: Bool {
        let ext = URL(string: document.fileURL)?.pathExtension.lowercased() ?? ""
        return ["jpg", "jpeg", "png", "heic"].contains(ext)
    }

    private var iconBadge: some View {
        Image(systemName: "doc.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.blue)
            .frame(width: 30, height: 30)
            .background(Color.blue.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
