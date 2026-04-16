import SwiftUI

struct AddVehicleStep2View: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // MARK: Header Progress
                VStack(spacing: 8) {
                    HStack {
                        Text("REGISTRATION PROGRESS")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(.systemGray))
                        
                        Spacer()
                        
                        Text("STEP 2 OF 2")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(.systemGray))
                    }
                    
                    // Progress Bar
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray4))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color.primaryBrown)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 4)
                    }
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
        .navigationTitle("Add Vehicle")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    AddVehicleStep2View()
}
