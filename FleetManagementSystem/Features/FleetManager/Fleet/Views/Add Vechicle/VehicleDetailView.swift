import SwiftUI
import Combine

struct VehicleDetailView: View {
    let vehicleId: UUID
    
    @StateObject private var vm = VehicleDetailViewModel()
    
    @State private var isEditing = false
    @State private var draftVehicle: Vehicle?
    @State private var isSaving = false
    
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary

    var body: some View {
        ScrollView {
            if vm.isLoading {
                ProgressView()
                    .padding(.top, 60)
                
            } else if let vehicle = vm.vehicle {
                VStack(alignment: .leading, spacing: 22) {
                    
                    vehicleImage(vehicle)
                    vehicleHeader(vehicle)
                    infoSection(vehicle)
                    documentsSection
                    
                }
                .padding()
                
            } else if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 60)
            }
        }
        .onAppear {
            Task {
                await vm.fetchVehicle(vehicleId: vehicleId)
            }
        }
        .navigationTitle("Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: sourceType) { image in
                Task {
                    await vm.uploadImage(image: image, type: "VEHICLE")
                }
            }
        }
    }

    // MARK: - IMAGE

    private func vehicleImage(_ vehicle: Vehicle) -> some View {
        Group {
            if let urlString = vehicle.imageURL,
               let url = URL(string: urlString) {
                
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
                
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            showImagePicker = true
        }
    }

    // MARK: - HEADER
    
    private func vehicleHeader(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vehicle.name)
                .font(.title.bold())

            Text(vehicle.registrationNumber)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - INFO

    private func infoSection(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Info")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                InfoRow(title: "Brand", value: vehicle.brand ?? "—")
                InfoRow(title: "Model", value: vehicle.model ?? "—")
                InfoRow(title: "Year", value: vehicle.modelYear ?? "—")
                InfoRow(title: "Fuel", value: vehicle.fuelType ?? "—")
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - DOCUMENTS

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Documents")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            VStack(spacing: 0) {

                if vm.documents.isEmpty {
                    Text("No documents")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(vm.documents) { doc in
                        DocumentRow(document: doc)
                    }
                }

            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let document: VehicleDocument

    var body: some View {
        HStack {
            Text(document.title)
            Spacer()
            Text("View")
                .foregroundColor(.blue)
        }
        .padding()
    }
}
