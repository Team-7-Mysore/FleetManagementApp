

import SwiftUI

struct AddVehicleView: View {
    @ObservedObject var fleetVM: FleetListViewModel
    @State private var navigateToStep2 = false
    @State private var showImagePicker = false
    @StateObject var vm = AddVehicleViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showImageOptionsPopover = false
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // By calling these variables, the compiler only has to
                // check one "expression" at a time.
                imageUploadSection
                vehicleInfoSection
                manufacturerSection
                identificationSection
                validitySection
                
                navigationAndActionButtons
            }
        }
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Add Vehicle").font(.headline)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left").foregroundColor(Color(.label))
                }
            }
        }
        .alert(item: Binding(
            get: { vm.errorMessage.map { ErrorWrapper(message: $0) } },
            set: { _ in vm.errorMessage = nil }
        )) { wrapper in
            Alert(title: Text("Error"), message: Text(wrapper.message))
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: sourceType) { image in
                vm.localVehicleImage = image
                Task {
                    await vm.uploadImage(image: image, type: "VEHICLE")
                }
            }
        }
    }
    
    // MARK: - Sub-Views
    
    private var imageUploadSection: some View {
        VStack(spacing: 12) {
            // Use Button + Popover instead of Menu
            Button(action: { showImageOptionsPopover = true }) {
                if let image = vm.localVehicleImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.TechBlue, lineWidth: 2))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
            }
            .popover(isPresented: $showImageOptionsPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                VStack(spacing: 0) {
                    Button(action: {
                        showImageOptionsPopover = false
                        sourceType = .camera
                        showImagePicker = true
                    }) {
                        Label("Take Photo", systemImage: "camera")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    
                    Divider()
                    
                    Button(action: {
                        showImageOptionsPopover = false
                        sourceType = .photoLibrary
                        showImagePicker = true
                    }) {
                        Label("Choose from Gallery", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
                .padding(.vertical, 8)
                .frame(width: 250)
                .presentationCompactAdaptation(.popover)
            }
            .padding(.top, 10)
            
            // Helper text stays outside the menu so it never hides
            Text("Upload Vehicle Image")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var vehicleInfoSection: some View {
        FormCard(title: "Vehicle Info", icon: "car.fill") {
            CustomTextField(title: "Vehicle Name", placeholder: "Silver Ghost V8", text: $vm.vehicleName)
            CustomTextField(
                title: "Registration Number",
                placeholder: "KA01AB1234",
                text: Binding(
                    get: { vm.registrationNumber },
                    set: { vm.registrationNumber = vm.formatPlate($0) }
                ),
                hint: "Format: KA-01-AB-1234"
            )
            CustomDropdown(title: "Vehicle Type", options: ["Truck", "Car", "Bike"], selection: $vm.vehicleType)
            CustomDropdown(title: "Fuel Type", options: ["Diesel", "Petrol", "Electric"], selection: $vm.fuelType, showDivider: false)
        }
    }
    
    private var manufacturerSection: some View {
        FormCard(title: "Manufacturer & Brand", icon: "gearshape.fill") {
            CustomTextField(title: "Brand", placeholder: "Toyota", text: $vm.brand)
            CustomTextField(title: "Manufacturer", placeholder: "Rolls Royce Heritage", text: $vm.manufacturer, isOptional: true)
            CustomTextField(title: "Model", placeholder: "Phantom Edition", text: $vm.model, isOptional: true)
            CustomTextField(title: "Model Year", placeholder: "2024", text: $vm.modelYear, isOptional: true)
                .keyboardType(.numberPad)
            CustomDateField(title: "Registration Date", date: $vm.registrationDate, showDivider: false, allowPastOnly: true)
        }
    }
    
    private var identificationSection: some View {
        FormCard(title: "Vehicle Identification", icon: "barcode.viewfinder") {
            CustomTextField(
                title: "VIN (Vehicle ID Number)",
                placeholder: "17-digit number",
                text: $vm.vin,
                hint: "Exactly 17 characters",
                showDivider: false
            )
        }
    }
    
    private var validitySection: some View {
        FormCard(title: "Validity", icon: "shield.fill") {
            CustomDateField(title: "PUC Expiry Date", date: $vm.pucExpiry, allowFutureOnly: true)
            CustomDateField(title: "RC Expiry Date", date: $vm.rcExpiry, showDivider: false, allowFutureOnly: true)
        }
    }
    
    private var navigationAndActionButtons: some View {
        VStack {
            NavigationLink(
                destination: AddVehicleStep2View(fleetVM: fleetVM, vm: vm),
                isActive: $navigateToStep2
            ) {
                EmptyView()
            }
            
            Button {
                if let error = vm.validateStep1() {
                    vm.errorMessage = error
                } else {
                    navigateToStep2 = true
                }
            } label: {
                Text("Next Step →")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(vm.isStep1Valid ? Color.TechBlue : Color.TechBlue.opacity(0.4))
                    .cornerRadius(25)
            }
            .padding()
        }
        .onChange(of: vm.isSuccess) { success in
            if success {
                dismiss()
            }
        }
    }
}
