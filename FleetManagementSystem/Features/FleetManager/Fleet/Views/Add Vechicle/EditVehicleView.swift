import SwiftUI
import Combine
import UniformTypeIdentifiers

struct EditVehicleView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: VehicleDetailViewModel
    
    @State private var draftVehicle: Vehicle
    @State private var isSaving = false
    
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    @State private var isImportingDocument = false
    @State private var activeDocumentType: String?

    init(vm: VehicleDetailViewModel, vehicle: Vehicle) {
        self.vm = vm
        _draftVehicle = State(initialValue: vehicle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Image") {
                    vehicleImageSection
                }
                
                Section("Vehicle Info") {
                    TextField("Vehicle Name", text: binding(\.name))
                    TextField("Registration Number", text: binding(\.registrationNumber))
                }
                
                Section("Basic Info") {
                    InfoRow(title: "Brand", value: "", isEditing: true, text: binding(\.brand))
                    InfoRow(title: "Model", value: "", isEditing: true, text: binding(\.model))
                    InfoRow(title: "Year", value: "", isEditing: true, text: binding(\.modelYear))
                    InfoRow(title: "Fuel", value: "", isEditing: true, text: binding(\.fuelType))
                }
                
                Section("Documents") {
                    let requiredTypes = ["RC", "INSURANCE", "PUC"]
                    ForEach(requiredTypes, id: \.self) { type in
                        let doc = vm.documents.first(where: { $0.type.uppercased() == type })
                        
                        Button {
                            activeDocumentType = type
                            isImportingDocument = true
                        } label: {
                            if let doc = doc {
                                DocumentRow(document: doc, isEditing: true)
                            } else {
                                missingDocumentRow(type: type)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
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
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.1)
                        ProgressView("Saving...")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(radius: 10)
                    }
                    .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: sourceType) { image in
                    Task {
                        await vm.uploadImage(image: image, type: "VEHICLE")
                        if let newURL = vm.vehicle?.imageURL {
                            draftVehicle.imageURL = newURL
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
    }

    private var vehicleImageSection: some View {
        HStack {
            Spacer()
            if let urlString = draftVehicle.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(Image(systemName: "car.fill").foregroundColor(.gray))
            }
            Spacer()
            Button("Change Photo") {
                sourceType = .photoLibrary
                showImagePicker = true
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func missingDocumentRow(type: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: type == "RC" ? "doc.text.fill" : (type == "INSURANCE" ? "shield.lefthalf.filled" : "doc.badge.gearshape"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 30, height: 30)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(type)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text("Not uploaded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }

    private func saveChanges() async {
        isSaving = true
        vm.vehicle = draftVehicle
        let success = await vm.updateVehicle()
        isSaving = false
        if success {
            dismiss()
        }
    }

    private func binding(_ keyPath: WritableKeyPath<Vehicle, String>) -> Binding<String> {
        Binding(
            get: { draftVehicle[keyPath: keyPath] },
            set: { draftVehicle[keyPath: keyPath] = $0 }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<Vehicle, String?>) -> Binding<String> {
        Binding(
            get: { draftVehicle[keyPath: keyPath] ?? "" },
            set: { draftVehicle[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}
