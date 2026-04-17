import SwiftUI

struct AddVehicleStep2View: View {
    @State private var showSourcePicker = false
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: AddVehicleViewModel

    @State private var selectedType: String = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                
                VStack(spacing: 8) {
                    Text("2 of 2")
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
                        showSourcePicker = true
                    }
                    DocumentUploadComponent(
                        title: "INSURANCE DOCUMENT",
                        isUploaded: vm.insuranceURL != nil,
                        fileName: vm.insuranceURL
                    ).onTapGesture {
                        selectedType = "INSURANCE"
                        showSourcePicker = true
                    }
                    
                    DocumentUploadComponent(
                        title: "PUC CERTIFICATE (OPTIONAL)",
                        isUploaded: vm.pucURL != nil,
                        fileName: vm.pucURL
                    ).onTapGesture {
                        selectedType = "PUC"
                        showSourcePicker = true
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal)
                
               
                Button(action: {
                    Task {
                            await vm.saveVehicle()
                        }
                   
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

       
        .onChange(of: vm.isSuccess) { success in
            if success {
                dismiss()
            }
        }
    }
       
}

#Preview {
    AddVehicleStep2View(vm: AddVehicleViewModel())
    }
struct ErrorWrapper: Identifiable {
    let id = UUID()
    let message: String
}
