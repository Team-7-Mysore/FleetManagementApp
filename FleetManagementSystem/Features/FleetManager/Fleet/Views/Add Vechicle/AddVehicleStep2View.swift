import SwiftUI

struct AddVehicleStep2View: View {
    @Environment(\.dismiss) var dismiss
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
                
                // MARK: Documents White Card
                VStack(spacing: 24) {
                    DocumentUploadComponent(
                        title: "RC DOCUMENT",
                        isUploaded: true,
                        fileName: "RC_Vehicle_01.pdf"
                    )
                    
                    DocumentUploadComponent(
                        title: "INSURANCE DOCUMENT",
                        isUploaded: false
                    )
                    
                    DocumentUploadComponent(
                        title: "PUC CERTIFICATE (OPTIONAL)",
                        isUploaded: false
                    )
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal)
                
                // MARK: CTA
                Button(action: {
                    // Save vehicle action
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
    }
}

#Preview {
    AddVehicleStep2View()
}
