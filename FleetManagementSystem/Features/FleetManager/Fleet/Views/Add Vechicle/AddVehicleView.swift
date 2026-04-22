import SwiftUI
import AVFoundation
import Photos

struct ErrorWrapper: Identifiable {
    var id: String { message }
    let message: String
}

struct AddVehicleView: View {
    @ObservedObject var fleetVM: FleetListViewModel
    @StateObject var vm = AddVehicleViewModel()
    @Environment(\.dismiss) var dismiss
    
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedType: String = ""

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Vehicle Photo
                Section {
                    HStack {
                        Spacer()
                        imageUploadSection
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // MARK: - Vehicle Identification
                Section(header: Text("Vehicle Identification")) {
                    TextField("Vehicle Name", text: $vm.vehicleName)
                    
                    let plateBinding = Binding(
                        get: { vm.licensePlate },
                        set: { vm.licensePlate = vm.formatPlate($0) }
                    )
                    TextField("License Plate", text: plateBinding)
                    
                    TextField("VIN", text: $vm.vin)
                    TextField("RC Number", text: $vm.rcNumber)
                    TextField("Brand", text: $vm.brand)
                }
                
                // MARK: - Manufacturer & Specs
                Section(header: Text("Manufacturer & Specs")) {
                    TextField("Manufacturer", text: $vm.manufacturer)
                    TextField("Model", text: $vm.model)
                    
                    Picker("Vehicle Type", selection: $vm.vehicleType) {
                        Text("Select Type").tag("")
                        ForEach(["Truck", "Car", "Bike"], id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    Picker("Fuel Type", selection: $vm.fuelType) {
                        Text("Select Fuel").tag("")
                        ForEach(["Diesel", "Petrol", "Electric"], id: \.self) { fuel in
                            Text(fuel).tag(fuel)
                        }
                    }
                }
                
                // MARK: - Required Documents
                Section(header: Text("Required Documents")) {
                    documentRow(title: "RC Document", isUploaded: vm.rcURL != nil, fileName: vm.rcFileName, type: "RC")
                    documentRow(title: "Insurance Policy", isUploaded: vm.insuranceURL != nil, fileName: vm.insuranceFileName, type: "INSURANCE")
                    documentRow(title: "PUC Certificate", isUploaded: vm.pucURL != nil, fileName: vm.pucFileName, type: "PUC")
                }
                
                // MARK: - Validity
                Section(header: Text("Validity")) {
                    DatePicker("Registration Date", selection: $vm.registrationDate, displayedComponents: .date)
                    DatePicker("PUC Expiry", selection: $vm.pucExpiry, displayedComponents: .date)
                    DatePicker("RC Expiry", selection: $vm.rcExpiry, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await vm.saveVehicle() }
                    }
                    .disabled(!vm.isFormValid || vm.isLoading)
                    .overlay {
                        if vm.isLoading { ProgressView() }
                    }
                }
            }
            .alert(item: Binding(
                get: { vm.errorMessage.map { ErrorWrapper(message: $0) } },
                set: { _ in vm.errorMessage = nil }
            )) { wrapper in
                Alert(title: Text("Note"), message: Text(wrapper.message))
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in
                    handleDocumentSelected(url)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: sourceType) { image in
                    handleImageSelected(image)
                }
            }
            .onChange(of: vm.isSuccess) { success in
                if success {
                    Task { await fleetVM.fetchVehicles() }
                    dismiss()
                }
            }
        }
    }

    // MARK: - Handlers
    
    private func handleImageSelected(_ image: UIImage) {
        self.vm.localVehicleImage = image
        let uploadType = self.selectedType
        let viewModel = self.vm
        Task { await viewModel.uploadImage(image: image, type: uploadType) }
    }

    private func handleDocumentSelected(_ url: URL) {
        let uploadType = self.selectedType
        let viewModel = self.vm
        Task { await viewModel.uploadFile(fileURL: url, type: uploadType) }
    }
    
    // MARK: - Subcomponents

    private var imageUploadSection: some View {
        Menu {
            Button {
                handleCameraAccess {
                    sourceType = .camera
                    selectedType = "VEHICLE"
                    showImagePicker = true
                }
            } label: { Label("Take Photo", systemImage: "camera") }
            
            Button {
                handlePhotoLibraryAccess {
                    sourceType = .photoLibrary
                    selectedType = "VEHICLE"
                    showImagePicker = true
                }
            } label: { Label("Choose from Gallery", systemImage: "photo") }
        } label: {
            VStack(spacing: 8) {
                if let image = vm.localVehicleImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 100, height: 100)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                    }
                }
                Text("Set Vehicle Photo")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
        }
    }

    private func documentRow(title: String, isUploaded: Bool, fileName: String?, type: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let fileName = fileName, isUploaded {
                    Text(fileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Menu {
                Button {
                    selectedType = type
                    showDocumentPicker = true
                } label: { Label("Files", systemImage: "folder") }
                
                Button {
                    selectedType = type
                    handlePhotoLibraryAccess {
                        sourceType = .photoLibrary
                        showImagePicker = true
                    }
                } label: { Label("Photos", systemImage: "photo") }
            } label: {
                HStack(spacing: 4) {
                    Text(isUploaded ? "Replace" : "Upload")
                    Image(systemName: isUploaded ? "arrow.triangle.2.circlepath" : "chevron.right")
                }
                .font(.system(size: 14, weight: .medium))
            }
        }
    }

    // MARK: - Permissions
    
    private func handleCameraAccess(onGranted: @escaping () -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized { onGranted() }
        else {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { onGranted() } }
            }
        }
    }

    private func handlePhotoLibraryAccess(onGranted: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited { onGranted() }
        else {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized || status == .limited {
                    DispatchQueue.main.async { onGranted() }
                }
            }
        }
    }
}
