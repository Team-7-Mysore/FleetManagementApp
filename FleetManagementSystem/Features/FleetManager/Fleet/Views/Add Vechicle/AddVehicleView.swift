import SwiftUI

struct AddVehicleView: View {
    @State private var vehicleName = ""
    @State private var registrationNumber = ""
    @State private var vehicleType = "Truck"
    @State private var fuelType = "Diesel"
    @State private var manufacturer = ""
    @State private var model = ""

    @State private var registrationDate = Date()
    @State private var pucExpiry = Date()
    @State private var rcExpiry = Date()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
       
        ScrollView {
            VStack(spacing: 20) {
                
             
                VStack(spacing: 8) {

                    Text("1 of 2")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.label))
                        
                  
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray5))
                                .frame(height: 3)
                            
                            Capsule()
                                .fill(Color.primaryBrown)
                                .frame(width: geometry.size.width * 0.5, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .padding(.horizontal)
                
                
                FormCard(title: "Vehicle Info", icon: "car.fill") {
                    
                    CustomTextField(
                        title: "VEHICLE NAME",
                        placeholder: "e.g. Silver Ghost V8",
                        text: $vehicleName
                    )

                    CustomTextField(
                        title: "REGISTRATION NUMBER",
                        placeholder: "ABC-1234",
                        text: $registrationNumber
                    )
                    HStack(spacing: 16) {
                           CustomDropdown(
                               title: "VEHICLE TYPE",
                               options: ["Truck", "Car", "Bike"],
                               selection: $vehicleType
                           )
                           
                           CustomDropdown(
                               title: "FUEL TYPE",
                               options: ["Diesel", "Petrol", "Electric"],
                               selection: $fuelType
                           )
                       }
                }
                
               
                FormCard(title: "Basic Details", icon: "gearshape.fill") {
                    
                    CustomTextField(
                        title: "MANUFACTURER",
                        placeholder: "Rolls Royce Heritage",
                        text: $manufacturer
                    )
                    
                    CustomTextField(
                        title: "MODEL",
                        placeholder: "Phantom Edition",
                        text: $model
                    )
                    
                    CustomDateField(
                        title: "REGISTRATION DATE",
                        date: $registrationDate
                    )
                }
              
                FormCard(title: "Validity", icon: "shield.fill") {
                    HStack(spacing: 16) {
                        
                        CustomDateField(
                            title: "PUC EXPIRY DATE",
                            date: $pucExpiry
                        )
                        
                        CustomDateField(
                            title: "RC EXPIRY DATE",
                            date: $rcExpiry
                        )
                    }
                }
                
             
                NavigationLink(destination: AddVehicleStep2View()) {
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
      
    }
}
