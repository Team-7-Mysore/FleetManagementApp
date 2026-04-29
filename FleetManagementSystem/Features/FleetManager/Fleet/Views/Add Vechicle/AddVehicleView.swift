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

    @State private var showSourcePopover = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        imageUploadSection
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .listRowBackground(Color.clear)

                Section(header: sectionHeader("Required Documents")) {
                    documentRow(title: "RC Document", isUploaded: vm.rcURL != nil, fileName: vm.rcFileName, type: "RC")
                    documentRow(title: "Insurance", isUploaded: vm.insuranceURL != nil, fileName: vm.insuranceFileName, type: "INSURANCE")
                    documentRow(title: "PUC", isUploaded: vm.pucURL != nil, fileName: vm.pucFileName, type: "PUC")
                }

                Section(header: sectionHeader("Vehicle Identification")) {

                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Vehicle Name")
                        TextField("Enter Name", text: $vm.vehicleName)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("License Plate")
                        TextField("AA-00-AA-0000", text: $vm.licensePlate)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                            .onChange(of: vm.licensePlate) { _, newValue in
                                let formatted = vm.formatPlate(newValue)
                                if formatted != newValue { vm.licensePlate = formatted }
                            }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("VIN")
                        TextField("Enter 17-digit VIN", text: Binding(
                            get: { vm.vin },
                            set: { vm.vin = String($0.uppercased().prefix(17)) }
                        ))
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Brand")
                        TextField("Enter Brand", text: $vm.brand)
                    }.padding(.vertical, 4)
                }

                Section(header: sectionHeader("Manufacturer & Specs")) {
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Manufacturer")
                        TextField("Enter Manufacturer", text: $vm.manufacturer)
                    }.padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Model")
                        TextField("Enter Model", text: $vm.model)
                    }.padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Model Year")
                        TextField("e.g. 2024", text: $vm.modelYear)
                            .keyboardType(.numberPad)
                            .onChange(of: vm.modelYear) { _, newValue in
                                let filtered = newValue.filter { "0123456789".contains($0) }
                                vm.modelYear = String(filtered.prefix(4))
                            }
                    }.padding(.vertical, 4)

                    Picker("Vehicle Type", selection: $vm.vehicleType) {
                        ForEach(["Truck", "Car", "Bike", "Bus"], id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Fuel Type", selection: $vm.fuelType) {
                        ForEach(["Petrol", "Diesel", "Electric", "CNG", "Hybrid"], id: \.self) { Text($0).tag($0) }
                    }
                    
                    Toggle("SDV Enabled", isOn: $vm.isSdvsEnabled)
                }


                if vm.rcURL != nil || vm.pucURL != nil {
                    Section(header: sectionHeader("Validity")) {
                        if vm.rcURL != nil {
                            DatePicker("Registration Date", selection: $vm.registrationDate, displayedComponents: .date)
                            DatePicker("RC Expiry", selection: $vm.rcExpiry, displayedComponents: .date)
                        }
                        
                        if vm.pucURL != nil {
                            DatePicker("PUC Expiry", selection: $vm.pucExpiry, displayedComponents: .date)
                        }
                    }

                }
            }
            .hideKeyboardOnTap()
            .navigationTitle("Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {

                    Button("Save") { Task { await vm.saveVehicle() } }
                        .disabled(!vm.isFormValid)
                }
            }
            .sheet(isPresented: $showDocumentPicker) { DocumentPicker { url in handleDocumentSelected(url) } }
            .sheet(isPresented: $showImagePicker) { ImagePicker(sourceType: sourceType) { image in handleImageSelected(image) } }
            .onChange(of: vm.isSuccess) { _, newValue in
                if newValue {
                    dismiss()
                    Task {
                        await fleetVM.fetchVehicles()
                    }
                }
            }
        }
    }

    private func documentRow(title: String, isUploaded: Bool, fileName: String?, type: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold))

                if let fileName = fileName, isUploaded {
                    Text(fileName).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            
            Button(isUploaded ? "Replace" : "Upload") {
                selectedType = type
                showSourcePopover = true
            }
            .buttonStyle(.borderless)
            .popover(isPresented: Binding(
                get: { showSourcePopover && selectedType == type },
                set: { if !$0 { showSourcePopover = false } }
            )) {
                sourcePickerContents
                    .presentationCompactAdaptation(.popover)
                    .frame(width: 200)
                    .padding(.vertical, 8)
            }
        }
    }


    private var sourcePickerContents: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                handleCameraAccess { sourceType = .camera; showImagePicker = true; showSourcePopover = false }
            }) {
                HStack {
                    Image(systemName: "camera")
                    Text("Camera")
                    Spacer()
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Divider()

            Button(action: {
                handlePhotoLibraryAccess { sourceType = .photoLibrary; showImagePicker = true; showSourcePopover = false }
            }) {
                HStack {
                    Image(systemName: "photo.on.rectangle")
                    Text("Gallery")
                    Spacer()
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Divider()

            Button(action: {
                showDocumentPicker = true; showSourcePopover = false
            }) {
                HStack {
                    Image(systemName: "folder")
                    Text("Files")
                    Spacer()
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
        }
    }


    private var imageUploadSection: some View {
        Button {
            selectedType = "VEHICLE"
            showSourcePopover = true
        } label: {
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
        .popover(isPresented: Binding(
            get: { showSourcePopover && selectedType == "VEHICLE" },
            set: { if !$0 { showSourcePopover = false } }
        )) {
            sourcePickerContents
                .presentationCompactAdaptation(.popover)
                .frame(width: 200)
                .padding(.vertical, 8)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.system(size: 18, weight: .bold)).foregroundColor(.secondary).textCase(nil)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .bold)).foregroundColor(Color(.systemGray2))
    }

    private func handleImageSelected(_ image: UIImage) {
        if selectedType == "VEHICLE" { vm.localVehicleImage = image }
        Task {
            await vm.uploadImage(image: image, type: selectedType)
            if selectedType == "RC" { await vm.processVehicleOCR(from: image) }
        }
    }

    private func handleDocumentSelected(_ url: URL) {
        let uploadType = self.selectedType
        Task {
            await vm.uploadFile(fileURL: url, type: uploadType)
            if uploadType == "RC" {
                await vm.processVehicleOCR(from: url)
            }
        }
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
                if status == .authorized || status == .limited { DispatchQueue.main.async { onGranted() } }
            }
        }
    }
}
