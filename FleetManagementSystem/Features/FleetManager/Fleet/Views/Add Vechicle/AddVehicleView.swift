import SwiftUI

struct AddVehicleView: View {
    @StateObject var vm = AddVehicleViewModel()
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
                
             
                NavigationLink(destination: AddVehicleStep2View(vm: vm)){
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
extension AddVehicleViewModel {
    
    func saveVehicle() async {
        
        guard let url = URL(string: "\(SUPABASE_URL)/functions/v1/create-vehicle-with-documents") else {
            return
        }
        
        let payload: [String: Any] = [
            "vehicleName": vehicleName,
            "registrationNumber": registrationNumber,
            "vehicleType": vehicleType,
            "fuelType": fuelType,
            "manufacturer": manufacturer,
            "model": model,
            "registrationDate": ISO8601DateFormatter().string(from: registrationDate),
            "pucExpiry": ISO8601DateFormatter().string(from: pucExpiry),
            "rcExpiry": ISO8601DateFormatter().string(from: rcExpiry),
            "documents": [
                ["type": "RC", "url": rcURL ?? ""],
                ["type": "INSURANCE", "url": insuranceURL ?? ""],
                ["type": "PUC", "url": pucURL ?? ""]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.addValue("Content-Type", forHTTPHeaderField: "application/json")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            print("Saved:", response)
        } catch {
            print("Error saving vehicle:", error)
        }
    }
}
