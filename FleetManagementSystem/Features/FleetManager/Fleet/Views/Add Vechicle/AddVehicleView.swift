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
                // MARK: - Vehicle Photo
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
                    
                    // Plate Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("License Plate")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                        
                        TextField("AA-00-AA-0000", text: $vm.licensePlate)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                            .onChange(of: vm.licensePlate) { _, newValue in
                                let formatted = vm.formatPlate(newValue)
                                if formatted != newValue {
                                    vm.licensePlate = formatted
                                }
                            }
                        
                        if !vm.licensePlate.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: vm.isPlateValidCheck ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text(vm.isPlateValidCheck ? "Valid Format" : "Invalid (AA-00-AA-0000)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(vm.isPlateValidCheck ? .green : .red)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // VIN Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VIN")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                            
                        TextField("Enter 17-digit VIN", text: Binding(
                            get: { vm.vin },
                            set: { vm.vin = String($0.uppercased().prefix(17)) }
                        ))
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        
                        if !vm.vin.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: vm.vin.count == 17 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text(vm.vin.count == 17 ? "Valid VIN" : "Incomplete VIN")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(vm.vin.count == 17 ? .green : .red)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RC Number")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                        TextField("Enter RC Number", text: $vm.rcNumber)
                    }.padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Brand")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(.systemGray2))
                        TextField("Enter Brand", text: $vm.brand)
                    }.padding(.vertical, 4)
                }
                
                // MARK: - Specs
                Section(header: Text("Manufacturer & Specs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(nil)
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Manufacturer").font(.system(size: 16, weight: .bold)).foregroundColor(Color(.systemGray2))
                        TextField("Enter Manufacturer", text: $vm.manufacturer)
                    }.padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model").font(.system(size: 16, weight: .bold)).foregroundColor(Color(.systemGray2))
                        TextField("Enter Model", text: $vm.model)
                    }.padding(.vertical, 4)
                    
                    Picker("Vehicle Type", selection: $vm.vehicleType) {
                        ForEach(["Truck", "Car", "Bike", "Bus"], id: \.self) { Text($0).tag($0) }
                    }
                    
                    Picker("Fuel Type", selection: $vm.fuelType) {
                        ForEach(["Petrol", "Diesel", "Electric", "CNG", "Hybrid"], id: \.self) { Text($0).tag($0) }
                    }
                }
                
                // MARK: - Docs & Dates
                Section(header: Text("Required Documents").font(.headline)) {
                    documentRow(title: "RC Document", isUploaded: vm.rcURL != nil, fileName: vm.rcFileName, type: "RC")
                    documentRow(title: "Insurance", isUploaded: vm.insuranceURL != nil, fileName: vm.insuranceFileName, type: "INSURANCE")
                    documentRow(title: "PUC", isUploaded: vm.pucURL != nil, fileName: vm.pucFileName, type: "PUC")
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await vm.saveVehicle() } }
                    .disabled(!vm.isFormValid)
                }
            }
            .sheet(isPresented: $showDocumentPicker) { DocumentPicker { url in handleDocumentSelected(url) } }
            .sheet(isPresented: $showImagePicker) { ImagePicker(sourceType: sourceType) { image in handleImageSelected(image) } }
            .confirmationDialog("Change Photo", isPresented: $showImageSourceOptions) {
                Button("Camera") { handleCameraAccess { sourceType = .camera; showImagePicker = true } }
                Button("Gallery") { handlePhotoLibraryAccess { sourceType = .photoLibrary; showImagePicker = true } }
            }
            .onChange(of: vm.isSuccess) { if $0 { Task { await fleetVM.fetchVehicles() }; dismiss() } }
        }
    }

    // Handlers
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
        }.buttonStyle(.plain)
    }

    private func documentRow(title: String, isUploaded: Bool, fileName: String?, type: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .medium))
                if let fileName = fileName, isUploaded { Text(fileName).font(.caption).foregroundColor(.secondary).lineLimit(1) }
            }
            Spacer()
            Button(isUploaded ? "Replace" : "Upload") { selectedType = type; showDocumentPicker = true }.buttonStyle(.borderless)
        }
    }

    private func handleImageSelected(_ image: UIImage) { self.vm.localVehicleImage = image; self.selectedType = "VEHICLE"; Task { await vm.uploadImage(image: image, type: "VEHICLE") } }
    private func handleDocumentSelected(_ url: URL) { let uploadType = self.selectedType; Task { await vm.uploadFile(fileURL: url, type: uploadType) } }
    private func handleCameraAccess(onGranted: @escaping () -> Void) { let status = AVCaptureDevice.authorizationStatus(for: .video); if status == .authorized { onGranted() } else { AVCaptureDevice.requestAccess(for: .video) { if $0 { DispatchQueue.main.async { onGranted() } } } } }
    private func handlePhotoLibraryAccess(onGranted: @escaping () -> Void) { let status = PHPhotoLibrary.authorizationStatus(for: .readWrite); if status == .authorized || status == .limited { onGranted() } else { PHPhotoLibrary.requestAuthorization(for: .readWrite) { if $0 == .authorized { DispatchQueue.main.async { onGranted() } } } } }
}
