import SwiftUI

struct AddVehicleStep2View: View {
    @ObservedObject var fleetVM: FleetListViewModel
    @State private var showSourcePicker = false
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: AddVehicleViewModel

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
                                .fill(Color.TechBlue)
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
                        title: "RC Document",
                        isUploaded: vm.rcURL != nil,
                        fileName: vm.rcURL
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    selectedType = "INSURANCE"
                    showSourcePicker = true
                }) {
                    DocumentUploadComponent(
                        title: "Insurance Document",
                        isUploaded: vm.insuranceURL != nil,
                        fileName: vm.insuranceURL
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    selectedType = "PUC"
                    showSourcePicker = true
                }) {
                    DocumentUploadComponent(
                        title: "PUC Certificate (Optional)",
                        isUploaded: vm.pucURL != nil,
                        fileName: vm.pucURL
                    )
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
                    .background(Color.TechBlue)
                    .cornerRadius(25)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                Spacer(minLength: 40)

            }
            
            Section {
                Button(action: {
                    Task {
                        await vm.saveVehicle()
                    }
                }) {
                    Text("Save Vehicle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.TechBlue)
                .foregroundColor(.white)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Add Vehicle")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(.label))
                }
            }
        }
        .confirmationDialog("Select Source", isPresented: $showSourcePicker) {
            
            Button("Choose File") {
                showDocumentPicker = true
            }
            
            Button("Choose Photo") {
                showImagePicker = true
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { url in
                Task {
                    await vm.uploadFile(fileURL: url, type: selectedType)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { image in
                Task {
                    await vm.uploadImage(image: image, type: selectedType)
                }
            }
        }

        .onChange(of: vm.isSuccess) { success in
            if success {
                Task {
                    await fleetVM.fetchVehicles()   // 🔥 refresh first
                    
                    // then go back
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
            }
        }
    }
       
}

#Preview {
    AddVehicleStep2View(
        fleetVM: FleetListViewModel(), vm: AddVehicleViewModel()
      )
    }
struct ErrorWrapper: Identifiable {
    var id: String { message }
    let message: String
}
