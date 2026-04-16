import SwiftUI

struct AddVehicleView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
       
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: Header
                VStack(spacing: 8) {

                    Text("1 of 2")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(.label))
                        
                    // Progress Bar
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
                
                // MARK: Vehicle Info
                FormCard(title: "Vehicle Info", icon: "car.fill") {
                    
                    CustomTextField(title: "VEHICLE NAME", placeholder: "e.g. Silver Ghost V8")
                    
                    CustomTextField(title: "REGISTRATION NUMBER", placeholder: "ABC-1234")
                    HStack(spacing: 16) {
                        CustomDropdown(title: "VEHICLE TYPE", value: "Commercial Truck")
                        
                        CustomDropdown(title: "FUEL TYPE", value: "Diesel")
                    }
                }
                
                // MARK: Basic Details
                FormCard(title: "Basic Details", icon: "gearshape.fill") {
                    
                    CustomTextField(title: "MANUFACTURER", placeholder: "Rolls Royce Heritage")
                    
                    CustomTextField(title: "MODEL", placeholder: "Phantom Edition")
                    
                    CustomDateField(title: "REGISTRATION DATE")
                }
                
                // MARK: Validity
                FormCard(title: "Validity", icon: "shield.fill") {
                    HStack(spacing: 16) {
                        CustomDateField(title: "PUC EXPIRY DATE")
                        
                        CustomDateField(title: "RC EXPIRY DATE")
                    }
                }
                
                // MARK: CTA
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
