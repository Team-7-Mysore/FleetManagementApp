import SwiftUI

struct AddVehicleStep2View: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: AddVehicleViewModel
    @State private var showPicker = false
    @State private var selectedType: String = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: Header Progress
                VStack(spacing: 8) {
                    Text("2 of 2")
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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 3)
                        }
                    }
                    .frame(height: 3)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                VStack(spacing: 24) {
                    
                    DocumentUploadComponent(
                        title: "RC DOCUMENT",
                        isUploaded: vm.rcURL != nil,
                        fileName: vm.rcURL
                    )
                    .onTapGesture {
                        selectedType = "RC"
                        showPicker = true
                    }
                    
                    DocumentUploadComponent(
                        title: "INSURANCE DOCUMENT",
                        isUploaded: vm.insuranceURL != nil,
                        fileName: vm.insuranceURL
                    ).onTapGesture {
                        selectedType = "INSURANCE"
                        showPicker = true
                    }
                    
                    DocumentUploadComponent(
                        title: "PUC CERTIFICATE (OPTIONAL)",
                        isUploaded: vm.pucURL != nil,
                        fileName: vm.pucURL
                    ).onTapGesture {
                        selectedType = "PUC"
                        showPicker = true
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal)
                
               
                Button(action: {
                   
                }) {
                    HStack {
                        Text("SAVE VEHICLE")
                            .fontWeight(.bold)
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primaryBrown)
                    .cornerRadius(25)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer(minLength: 40)
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
                    Task {
                            await vm.saveVehicle()
                        }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(.label))
                }
            }
        }
        .sheet(isPresented: $showPicker) {
        DocumentPicker { url in
            Task {
                await vm.uploadFile(fileURL: url, type: selectedType)
            }
        }
    }
    }
       
}

#Preview {
    AddVehicleStep2View(vm: AddVehicleViewModel())
    }
