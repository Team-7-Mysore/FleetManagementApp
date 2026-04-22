import SwiftUI
import AVFoundation
import Photos

// Move this outside the struct to ensure it is in scope for the alert
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
        ZStack(alignment: .top) {
            Color(.systemGray6).ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    headerNavigation
                    imageUploadSection
                    
                    nativeSection(title: "Vehicle Identification") {
                        VStack(spacing: 0) {
                            CustomTextField(title: "Vehicle Name", placeholder: "e.g. Silver Ghost V8", text: $vm.vehicleName)
                            
                            let plateBinding = Binding(
                                get: { vm.licensePlate },
                                set: { vm.licensePlate = vm.formatPlate($0) }
                            )
                            CustomTextField(title: "License Plate", placeholder: "KA01AB1234", text: plateBinding)
                            
                            CustomTextField(title: "VIN", placeholder: "17-digit number", text: $vm.vin)
                            CustomTextField(title: "RC Number", placeholder: "Enter RC Number", text: $vm.rcNumber)
                            CustomTextField(title: "Brand", placeholder: "e.g. Toyota", text: $vm.brand, showDivider: false)
                        }
                    }
                    
                    nativeSection(title: "Manufacturer & Specs") {
                        VStack(spacing: 0) {
                            CustomTextField(title: "Manufacturer", placeholder: "Rolls Royce", text: $vm.manufacturer)
                            CustomTextField(title: "Model", placeholder: "Phantom", text: $vm.model)
                            CustomDropdown(title: "Vehicle Type", options: ["Truck", "Car", "Bike"], selection: $vm.vehicleType)
                            CustomDropdown(title: "Fuel Type", options: ["Diesel", "Petrol", "Electric"], selection: $vm.fuelType, showDivider: false)
                        }
                    }
                    
                    nativeSection(title: "Required Documents") {
                        VStack(spacing: 0) {
                            documentRow(title: "RC Document", isUploaded: vm.rcURL != nil, fileName: vm.rcFileName, type: "RC")
                            documentRow(title: "Insurance Policy", isUploaded: vm.insuranceURL != nil, fileName: vm.insuranceFileName, type: "INSURANCE")
                            documentRow(title: "PUC Certificate", isUploaded: vm.pucURL != nil, fileName: vm.pucFileName, type: "PUC", showDivider: false)
                        }
                    }
                    
                    nativeSection(title: "Validity") {
                        VStack(spacing: 0) {
                            CustomDateField(title: "Registration Date", date: $vm.registrationDate)
                            CustomDateField(title: "PUC Expiry", date: $vm.pucExpiry)
                            CustomDateField(title: "RC Expiry", date: $vm.rcExpiry, showDivider: false)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .alert(item: Binding(
            get: { vm.errorMessage.map { ErrorWrapper(message: $0) } },
            set: { _ in vm.errorMessage = nil }
        )) { wrapper in
            Alert(title: Text("Note"), message: Text(wrapper.message))
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: sourceType) { image in
                // Logic extracted to private func below
                handleImageSelected(image)
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                // Logic extracted to private func below
                handleDocumentSelected(url)
            }
        }
        .onChange(of: vm.isSuccess) { _, success in
            if success {
                Task { await fleetVM.fetchVehicles() }
                dismiss()
            }
        }
    }

   
        
        private func handleImageSelected(_ image: UIImage) {
            // Update the UI image locally
            self.vm.localVehicleImage = image
            
            // Capture properties locally to simplify the Task closure
            let uploadType = self.selectedType
            let viewModel = self.vm
            
            Task {
                // FIX: Use the captured 'viewModel' instance directly
                await viewModel.uploadImage(image: image, type: uploadType)
            }
        }

        private func handleDocumentSelected(_ url: URL) {
            let uploadType = self.selectedType
            let viewModel = self.vm
            
            Task {
                // FIX: Use the captured 'viewModel' instance directly
                await viewModel.uploadFile(fileURL: url, type: uploadType)
            }
        }
    
    private var headerNavigation: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4)
            }
            Spacer()
            Text("Add Vehicle").font(.system(size: 17, weight: .bold))
            Spacer()
            Button(action: {
                Task { await vm.saveVehicle() }
            }) {
                if vm.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("Save").font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(vm.isFormValid ? Color.blue : Color.gray.opacity(0.5))
            .clipShape(Capsule())
            .disabled(vm.isLoading)
        }
        .padding(.top, 10)
    }

    private func nativeSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.leading, 8)
            VStack(spacing: 0) { content() }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 4)
        }
    }

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
            VStack(spacing: 12) {
                ZStack {
                    if let image = vm.localVehicleImage {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 120, height: 120).clipShape(RoundedRectangle(cornerRadius: 24))
                    } else {
                        RoundedRectangle(cornerRadius: 24).fill(Color.white)
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.05), radius: 5)
                            .overlay(Image(systemName: "camera.fill").foregroundColor(.blue).font(.largeTitle))
                    }
                }
                Text("Tap to upload photo").font(.system(size: 13, weight: .medium)).foregroundColor(.blue)
            }
        }
        .padding(.top, 10)
    }

    private func documentRow(title: String, isUploaded: Bool, fileName: String?, type: String, showDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 16)).foregroundColor(.primary)
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
                        Text(isUploaded ? "Ready" : "Upload")
                        Image(systemName: isUploaded ? "checkmark.circle.fill" : "chevron.right")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isUploaded ? .green : .blue)
                }
            }
            .padding(16)
            if showDivider { Divider().padding(.leading, 16) }
        }
    }

    private func handleCameraAccess(onGranted: @escaping () -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized { onGranted() }
        else {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { if granted { onGranted() } }
            }
        }
    }

    private func handlePhotoLibraryAccess(onGranted: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited { onGranted() }
        else {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async { if status == .authorized || status == .limited { onGranted() } }
            }
        }
    }
}
