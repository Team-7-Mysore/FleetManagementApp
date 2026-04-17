

import SwiftUI

struct AddVehicleView: View {
    @State private var navigateToStep2 = false
    @State private var showImagePicker = false
    @StateObject var vm = AddVehicleViewModel()
    @Environment(\.dismiss) var dismiss
    
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
                    Image(systemName: "chevron.left").foregroundColor(Color(.label))
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
            ImagePicker { image in
                vm.localVehicleImage = image
                Task {
                    await vm.uploadImage(image: image, type: "VEHICLE")
                }
            }
        }
    }
    
    // MARK: - Sub-Views
    
    private var imageUploadSection: some View {
        VStack {
            Button {
                showImagePicker = true
            } label: {
                if let image = vm.localVehicleImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.TechBlue, lineWidth: 2))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.top, 10)
            
            Text("Upload Vehicle Image")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var vehicleInfoSection: some View {
        FormCard(title: "Vehicle Info", icon: "car.fill") {
            CustomTextField(title: "VEHICLE NAME", placeholder: "e.g. Silver Ghost V8", text: $vm.vehicleName)
            CustomTextField(title: "REGISTRATION NUMBER", placeholder: "ABC-1234", text: $vm.registrationNumber)
            HStack(spacing: 16) {
                CustomDropdown(title: "VEHICLE TYPE", options: ["Truck", "Car", "Bike"], selection: $vm.vehicleType)
                CustomDropdown(title: "FUEL TYPE", options: ["Diesel", "Petrol", "Electric"], selection: $vm.fuelType)
            }
        }
    }
    
    private var manufacturerSection: some View {
        // Consolidating the two "Basic Details" cards into one
        FormCard(title: "Manufacturer & Brand", icon: "gearshape.fill") {
            HStack {
                CustomTextField(title: "BRAND", placeholder: "e.g. Toyota", text: $vm.brand)
                CustomTextField(title: "MANUFACTURER", placeholder: "Rolls Royce Heritage", text: $vm.manufacturer)
            }
            HStack {
                CustomTextField(title: "MODEL", placeholder: "Phantom Edition", text: $vm.model)
                CustomTextField(title: "MODEL YEAR", placeholder: "2024", text: $vm.modelYear)
                    .keyboardType(.numberPad)
            }
            CustomDateField(title: "REGISTRATION DATE", date: $vm.registrationDate)
        }
    }
    
    private var identificationSection: some View {
        // This is where the VIN (17-digit number) lives
        FormCard(title: "Vehicle Identification", icon: "barcode.viewfinder") {
            CustomTextField(
                title: "VIN (VEHICLE ID NUMBER)",
                placeholder: "17-digit number",
                text: $vm.vin
            )
        }
    }
    
    private var validitySection: some View {
        FormCard(title: "Validity", icon: "shield.fill") {
            HStack(spacing: 16) {
                CustomDateField(title: "PUC EXPIRY DATE", date: $vm.pucExpiry)
                CustomDateField(title: "RC EXPIRY DATE", date: $vm.rcExpiry)
            }
        }
    }
    
    private var navigationAndActionButtons: some View {
        VStack {
            NavigationLink(destination: AddVehicleStep2View(vm: vm), isActive: $navigateToStep2) {
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
                    .background(Color.TechBlue)
                    .cornerRadius(25)
            }
            .padding()
        }
    }
}
