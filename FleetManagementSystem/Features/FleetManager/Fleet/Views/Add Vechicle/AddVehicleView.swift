import SwiftUI

struct AddVehicleView: View {
    @State private var navigateToStep2 = false
    @StateObject var vm = AddVehicleViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
       
        ScrollView {
            VStack(spacing: 20) {

                
                FormCard(title: "Vehicle Info", icon: "car.fill") {
                    
                    CustomTextField(
                        title: "VEHICLE NAME",
                        placeholder: "e.g. Silver Ghost V8",
                        text: $vm.vehicleName
                    )

                    CustomTextField(
                        title: "REGISTRATION NUMBER",
                        placeholder: "ABC-1234",
                        text: $vm.registrationNumber
                    )
                    HStack(spacing: 16) {
                           CustomDropdown(
                               title: "VEHICLE TYPE",
                               options: ["Truck", "Car", "Bike"],
                               selection: $vm.vehicleType
                           )
                           
                           CustomDropdown(
                               title: "FUEL TYPE",
                               options: ["Diesel", "Petrol", "Electric"],
                               selection: $vm.fuelType
                           )
                       }
                }
                
               
                FormCard(title: "Basic Details", icon: "gearshape.fill") {
                    
                    CustomTextField(
                        title: "MANUFACTURER",
                        placeholder: "Rolls Royce Heritage",
                        text: $vm.manufacturer
                    )
                    
                    CustomTextField(
                        title: "MODEL",
                        placeholder: "Phantom Edition",
                        text: $vm.model
                    )
                    
                    CustomDateField(
                        title: "REGISTRATION DATE",
                        date: $vm.registrationDate
                    )
                }
              
                FormCard(title: "Validity", icon: "shield.fill") {
                    HStack(spacing: 16) {
                        
                        CustomDateField(
                            title: "PUC EXPIRY DATE",
                            date: $vm.pucExpiry
                        )
                        
                        CustomDateField(
                            title: "RC EXPIRY DATE",
                            date: $vm.rcExpiry
                        )
                    }
                }
                
             
            
                NavigationLink(
                    destination: AddVehicleStep2View(vm: vm),
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
                        .background(Color.primaryBrown)
                        .cornerRadius(25)
                }
                .padding()
            }
        }
        .background(Color(.systemGray6))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Add Vehicle")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(.label))
                }
            }
        }
        .alert(item: Binding(
            get: {
                vm.errorMessage.map { ErrorWrapper(message: $0) }
            },
            set: { _ in vm.errorMessage = nil }
        )) { wrapper in
            Alert(
                title: Text("Error"),
                message: Text(wrapper.message)
            )
        }
      
    }
}
