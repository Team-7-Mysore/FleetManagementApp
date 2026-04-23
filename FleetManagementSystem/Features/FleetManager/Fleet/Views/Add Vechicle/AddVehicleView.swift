import SwiftUI
import AVFoundation
import Photos

struct AddVehicleView: View {
    @ObservedObject var fleetVM: FleetListViewModel
    @StateObject var vm = AddVehicleViewModel()
    @Environment(\.dismiss) var dismiss
    
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedType: String = ""
    
    // State for the Image Selection Pop-up
    @State private var showImageSourceOptions = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Vehicle Photo Section
                Section {
                    HStack {
                        Spacer()
                        imageUploadSection
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .listRowBackground(Color.clear)

                // MARK: - Vehicle Identification
                // UPDATED: Footer now only mentions VIN to avoid redundancy
                Section(header: Text("Vehicle Identification"), footer: Text("Note: VIN must be exactly 17 characters.")) {
                    
                    TextField("Vehicle Name", text: $vm.vehicleName)
                    
                    // Plate Field
                    VStack(alignment: .leading, spacing: 4) {
                        // Explicit Label for the Field
                        Text("License Plate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        let plateBinding = Binding(
                            get: { vm.licensePlate },
                            set: { vm.licensePlate = vm.formatPlate($0).uppercased() }
                        )
                        
                        // TextField with Placeholder/Prompt
                        TextField("AA 00 AA 0000", text: plateBinding)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                        
                        // Local status indicator for the plate
                        if !vm.licensePlate.isEmpty {
                            Text(vm.licensePlate.count >= 7 ? "✓ Valid Format" : "⚠ Incomplete Plate")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(vm.licensePlate.count >= 7 ? .green : .orange)
                        }
                    }
                    
                    // VIN Field with character counter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VIN")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                        TextField("Enter 17-digit VIN", text: $vm.vin)
                            .onChange(of: vm.vin) { newValue in
                                if newValue.count > 17 {
                                    vm.vin = String(newValue.prefix(17))
                                }
                            }
                        
                        Text("\(vm.vin.count)/17 Characters")
                            .font(.caption2)
                            .foregroundColor(vm.vin.count == 17 ? .green : .red)
                    }
                    
                    TextField("RC Number", text: $vm.rcNumber)
                    TextField("Brand", text: $vm.brand)
                }
                
                // MARK: - Manufacturer & Specs
                Section(header: Text("Manufacturer & Specs")) {
                    TextField("Manufacturer", text: $vm.manufacturer)
                    TextField("Model", text: $vm.model)
                    
                    Picker("Vehicle Type", selection: $vm.vehicleType) {
                        Text("Select Type").tag("")
                        ForEach(["Truck", "Car", "Bike", "Bus"], id: \.self) { type in
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
                    .disabled(!vm.isFormValid || vm.vin.count != 17 || vm.licensePlate.count < 7 || vm.isLoading)
                    .overlay {
                        if vm.isLoading { ProgressView() }
                    }
                }
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
            .confirmationDialog("Change Vehicle Photo", isPresented: $showImageSourceOptions, titleVisibility: .visible) {
                Button("Take Photo") {
                    handleCameraAccess {
                        sourceType = .camera
                        selectedType = "VEHICLE"
                        showImagePicker = true
                    }
                }
                Button("Choose from Gallery") {
                    handlePhotoLibraryAccess {
                        sourceType = .photoLibrary
                        selectedType = "VEHICLE"
                        showImagePicker = true
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .onChange(of: vm.isSuccess) { success in
                if success {
                    Task { await fleetVM.fetchVehicles() }
                    dismiss()
                }
            }
        }
    }

    // MARK: - Subcomponents
    private var imageUploadSection: some View {
        Button {
            showImageSourceOptions = true
        } label: {
            VStack(spacing: 12) {
                if let image = vm.localVehicleImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.systemGray5))
                            .frame(width: 140, height: 140)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
                
                Text("Set Vehicle Photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(.plain)
    }

    private func documentRow(title: String, isUploaded: Bool, fileName: String?, type: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let fileName = fileName, isUploaded {
                    Text(fileName).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Menu {
                Button { selectedType = type; showDocumentPicker = true } label: { Label("Files", systemImage: "folder") }
                Button { selectedType = type; handlePhotoLibraryAccess { sourceType = .photoLibrary; showImagePicker = true } } label: { Label("Photos", systemImage: "photo") }
            } label: {
                HStack(spacing: 4) {
                    Text(isUploaded ? "Replace" : "Upload")
                    Image(systemName: isUploaded ? "arrow.triangle.2.circlepath" : "chevron.right")
                }
                .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Handlers & Permissions
    private func handleImageSelected(_ image: UIImage) {
        self.vm.localVehicleImage = image
        self.selectedType = "VEHICLE"
        Task { await vm.uploadImage(image: image, type: "VEHICLE") }
    }

    private func handleDocumentSelected(_ url: URL) {
        let uploadType = self.selectedType
        Task { await vm.uploadFile(fileURL: url, type: uploadType) }
    }
    
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
