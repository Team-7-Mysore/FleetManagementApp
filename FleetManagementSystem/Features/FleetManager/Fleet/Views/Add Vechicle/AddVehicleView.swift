import SwiftUI

struct AddVehicleView: View {
    
    var body: some View {
       
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: Header
                VStack(spacing: 8) {
                    
                    
                                        
                    HStack {
                        Text("PROGRESS")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text("STEP 1 OF 2")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    // Progress Bar
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color.primaryBrown)
                            .frame(width: 120, height: 4)
                    }
                }
                .padding(.horizontal)
                
                // MARK: Vehicle Info
                FormCard(title: "Vehicle Info", icon: "car.fill") {
                    
                    CustomTextField(title: "VEHICLE NAME", placeholder: "e.g. Silver Ghost V8")
                    
                    CustomTextField(title: "REGISTRATION NUMBER", placeholder: "ABC-1234")
                    
                    CustomDropdown(title: "VEHICLE TYPE", value: "Commercial Truck")
                    
                    CustomDropdown(title: "FUEL TYPE", value: "Diesel")
                }
                
                // MARK: Basic Details
                FormCard(title: "Basic Details", icon: "gearshape.fill") {
                    
                    CustomTextField(title: "MANUFACTURER", placeholder: "Rolls Royce Heritage")
                    
                    CustomTextField(title: "MODEL", placeholder: "Phantom Edition")
                    
                    CustomDateField(title: "REGISTRATION DATE")
                }
                
                // MARK: Validity
                FormCard(title: "Validity", icon: "shield.fill") {
                    
                    CustomDateField(title: "RC EXPIRY DATE")
                    
                    CustomDateField(title: "PUC EXPIRY DATE")
                }
                
                // MARK: CTA
                Button {
                    // Next step
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
        .background(Color(.systemGray6) )
        .navigationTitle("Add Vehicle")
        .navigationBarTitleDisplayMode(.inline)
      
    }
}
