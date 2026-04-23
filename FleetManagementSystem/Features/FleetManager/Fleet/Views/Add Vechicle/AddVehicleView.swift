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
                Section(header: Text("Vehicle Identification")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(nil)
                ) {
                    
                    // Vehicle Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Vehicle Name")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                        TextField("Enter Name", text: $vm.vehicleName)
                    }
                    .padding(.vertical, 4)
                    
                    // Plate Field with Strict Length and Format Validation
                    VStack(alignment: .leading, spacing: 6) {
                        Text("License Plate")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                        
                        let plateBinding = Binding(
                            get: { vm.licensePlate },
                            set: { vm.licensePlate = vm.formatPlate($0) } // Enforces limit and format
                        )
                        
                        TextField("AA-00-AA-0000", text: plateBinding)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                        
                        if !vm.licensePlate.isEmpty {
                            Label(vm.isPlateValidCheck ? "Valid Format" : "Invalid Format (AA-00-AA-0000)",
                                  systemImage: vm.isPlateValidCheck ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(vm.isPlateValidCheck ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // VIN Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VIN")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                            
                        TextField("Enter 17-digit VIN", text: $vm.vin)
                            .onChange(of: vm.vin) { newValue in
                                if newValue.count > 17 {
                                    vm.vin = String(newValue.prefix(17))
                                }
                            }
                        
                        if !vm.vin.isEmpty {
                            Label(vm.vin.count == 17 ? "Valid VIN" : "Incomplete VIN",
                                  systemImage: vm.vin.count == 17 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(vm.vin.count == 17 ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RC Number")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                        TextField("Enter RC Number", text: $vm.rcNumber)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Brand")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                        TextField("Enter Brand", text: $vm.brand)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Manufacturer & Specs
                Section(header: Text("Manufacturer & Specs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(nil)
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Manufacturer")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                        TextField("Enter Manufacturer", text: $vm.manufacturer)
                    }.padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                        TextField("Enter Model", text: $vm.model)
                    }.padding(.vertical, 4)
                    
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
                
                Section(header: Text("Required Documents").font(.headline)) {
                    documentRow(title: "RC Document", isUploaded: vm.rcURL != nil, fileName: vm.rcFileName, type: "RC")
                    documentRow(title: "Insurance Policy", isUploaded: vm.insuranceURL != nil, fileName: vm.insuranceFileName, type: "INSURANCE")
                    documentRow(title: "PUC Certificate", isUploaded: vm.pucURL != nil, fileName: vm.pucFileName, type: "PUC")
                }
                
                Section(header: Text("Validity").font(.headline)) {
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
                    .disabled(!vm.isFormValid || vm.vin.count != 17 || !vm.isPlateValidCheck || vm.isLoading)
                }
            }
            // ... (Rest of the sheets/dialogs same as before)
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in handleDocumentSelected(url) }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: sourceType) { image in handleImageSelected(image) }
            }
            .confirmationDialog("Change Vehicle Photo", isPresented: $showImageSourceOptions, titleVisibility: .visible) {
                Button("Take Photo") { handleCameraAccess { sourceType = .camera; showImagePicker = true } }
                Button("Choose from Gallery") { handlePhotoLibraryAccess { sourceType = .photoLibrary; showImagePicker = true } }
                Button("Cancel", role: .cancel) { }
            }
            .onChange(of: vm.isSuccess) { success in
                if success { Task { await fleetVM.fetchVehicles() }; dismiss() }
            }
        }
    }
    
    // MARK: - Subcomponents (Rest of handlers same as previous code)
    private var imageUploadSection: some View {
        Button { showImageSourceOptions = true } label: {
            VStack(spacing: 12) {
                if let image = vm.localVehicleImage {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 140, height: 140).clipShape(RoundedRectangle(cornerRadius: 24))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24).fill(Color(.systemGray5)).frame(width: 140, height: 140)
                        Image(systemName: "camera.fill").font(.system(size: 40)).foregroundColor(.white)
                    }
                }
                Text("Set Vehicle Photo").font(.system(size: 16, weight: .medium)).foregroundColor(.blue)
            }
        }
        .buttonStyle(.plain)
    }

    private func documentRow(title: String, isUploaded: Bool, fileName: String?, type: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
                if let fileName = fileName, isUploaded { Text(fileName).font(.caption).foregroundColor(.secondary).lineLimit(1) }
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

    private func handleImageSelected(_ image: UIImage) { self.vm.localVehicleImage = image; self.selectedType = "VEHICLE"; Task { await vm.uploadImage(image: image, type: "VEHICLE") } }
    private func handleDocumentSelected(_ url: URL) { let uploadType = self.selectedType; Task { await vm.uploadFile(fileURL: url, type: uploadType) } }
    private func handleCameraAccess(onGranted: @escaping () -> Void) { let status = AVCaptureDevice.authorizationStatus(for: .video); if status == .authorized { onGranted() } else { AVCaptureDevice.requestAccess(for: .video) { granted in if granted { DispatchQueue.main.async { onGranted() } } } } }
    private func handlePhotoLibraryAccess(onGranted: @escaping () -> Void) { let status = PHPhotoLibrary.authorizationStatus(for: .readWrite); if status == .authorized || status == .limited { onGranted() } else { PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in if status == .authorized || status == .limited { DispatchQueue.main.async { onGranted() } } } } }
}
