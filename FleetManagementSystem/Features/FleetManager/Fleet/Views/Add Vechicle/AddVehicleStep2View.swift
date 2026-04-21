import SwiftUI

struct AddVehicleStep2View: View {
    @ObservedObject var fleetVM: FleetListViewModel
    @State private var showSourcePicker = false
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: AddVehicleViewModel
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showDocPopover = false
    @State private var activeDocType: String? = nil
    @State private var selectedType: String = ""
    var body: some View {
        List {
            Section(header: Text("Upload Documents")) {
                DocumentUploadComponent(
                    title: "RC Document",
                    isUploaded: vm.rcURL != nil,
                    fileName: vm.rcFileName
                ) {
                    uploadMenu(type: "RC", isUploaded: vm.rcURL != nil)
                }
                
                DocumentUploadComponent(
                    title: "Insurance Document",
                    isUploaded: vm.insuranceURL != nil,
                    fileName: vm.insuranceFileName
                ) {
                    uploadMenu(type: "INSURANCE", isUploaded: vm.insuranceURL != nil)
                }
                
                DocumentUploadComponent(
                    title: "PUC Certificate (Optional)",
                    isUploaded: vm.pucURL != nil,
                    fileName: vm.pucFileName
                ) {
                    uploadMenu(type: "PUC", isUploaded: vm.pucURL != nil)
                }
            }
            
            Section {
                Button(action: {
                    if let error = vm.validate() {
                        vm.errorMessage = error
                    } else {
                        Task {
                            await vm.saveVehicle()
                        }
                    }
                }) {
                    if vm.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .tint(.white)
                    } else {
                        Text("Save Vehicle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(vm.isStep2Valid ? Color.TechBlue : Color.TechBlue.opacity(0.4))
                .foregroundColor(.white)
                .disabled(vm.isLoading)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Add Vehicle")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(.label))
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                Task {
                    await vm.uploadFile(fileURL: url, type: selectedType)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: sourceType) { image in
                Task {
                    await vm.uploadImage(image: image, type: selectedType)
                }
            }
        }
        .alert(item: Binding(
            get: { vm.errorMessage.map { ErrorWrapper(message: $0) } },
            set: { _ in vm.errorMessage = nil }
        )) { wrapper in
            Alert(title: Text("Save Failed"), message: Text(wrapper.message))
        }

        .onChange(of: vm.isSuccess) { success in
            if success {
                Task {
                    await fleetVM.fetchVehicles()   // 🔥 refresh first
                    
                    // then go back
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func uploadMenu(type: String, isUploaded: Bool) -> some View {
        Button(action: {
            selectedType = type
            showDocPopover = true
        }) {
            HStack(spacing: 4) {
                Text(isUploaded ? "Replace" : "Upload")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: isUploaded ? "arrow.triangle.2.circlepath" : "square.and.arrow.up")
                    .font(.caption)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
        .popover(isPresented: Binding(
            get: { showDocPopover && selectedType == type },
            set: { if !$0 { showDocPopover = false } }
        ), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            VStack(spacing: 0) {
                Button(action: {
                    showDocPopover = false
                    showDocumentPicker = true
                }) {
                    Label("Choose File", systemImage: "doc")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                
                Divider()
                
                Button(action: {
                    showDocPopover = false
                    sourceType = .camera
                    showImagePicker = true
                }) {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                
                Divider()
                
                Button(action: {
                    showDocPopover = false
                    sourceType = .photoLibrary
                    showImagePicker = true
                }) {
                    Label("Choose Photo", systemImage: "photo")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
            .padding(.vertical, 8)
            .frame(width: 250)
            .presentationCompactAdaptation(.popover)
        }
    }
}

#Preview {
    AddVehicleStep2View(
        fleetVM: FleetListViewModel(), vm: AddVehicleViewModel()
      )
    }
struct ErrorWrapper: Identifiable {
    var id: String { message }
    let message: String
}
