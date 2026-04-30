import SwiftUI
import VisionKit
import Supabase

struct LogFuelView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gallons: String = ""
    @State private var totalCost: String = ""
    @State private var odometer: String = ""
    @State private var receiptImage: UIImage?
    @State private var showScanner = false
    @State private var isLoading = false
    @State private var uploadTaskError: String?

    // Add vehicle passing
    var vehicleId: UUID

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Fuel Details")) {
                    TextField("Volume (e.g. 10.5 gal)", text: $gallons)
                        .keyboardType(.decimalPad)
                    
                    TextField("Total Cost (e.g. $45.00)", text: $totalCost)
                        .keyboardType(.decimalPad)
                        
                    TextField("Odometer Reading", text: $odometer)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Receipt Image")) {
                    if let image = receiptImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                            .onTapGesture {
                                showScanner = true
                            }
                    } else {
                        Button(action: { showScanner = true }) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                Text("Scan Receipt")
                            }
                        }
                    }
                }
                
                if let error = uploadTaskError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Log Fuel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveFuelLog() }
                    }
                    .disabled(isLoading || gallons.isEmpty || totalCost.isEmpty)
                }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            ReceiptScanner(scannedImage: $receiptImage)
                .ignoresSafeArea()
        }
        .overlay {
            if isLoading {
                ProgressView("Saving...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
    }
    
    private func saveFuelLog() async {
        guard let volume = Double(gallons), let cost = Double(totalCost) else {
            uploadTaskError = "Invalid number format."
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            var imageUrl: String? = nil
            
            // 1. Upload Image to Supabase Storage if present
            if let image = receiptImage, let imageData = image.jpegData(compressionQuality: 0.8) {
                let fileName = "\(UUID().uuidString).jpg"
                let uploadPath = "\(vehicleId.uuidString)/\(fileName)"
                
                try await SupabaseManager.shared.client.storage
                    .from("fuel-receipts")
                    .upload(uploadPath, data: imageData, options: .init(contentType: "image/jpeg"))
                
                imageUrl = try SupabaseManager.shared.client.storage
                    .from("fuel-receipts")
                    .getPublicURL(path: uploadPath).absoluteString
            }
            
            // 2. Insert DB Record
            let newLog = FuelLog(
                id: UUID(),
                vehicleId: vehicleId,
                driverId: nil, // Current user id logic here
                tripId: nil,
                date: Date(),
                gallons: volume,
                totalCost: cost,
                mileageAtFill: Double(odometer),
                location: nil,
                receiptImageUrl: imageUrl
            )
            
            try await SupabaseManager.shared.client
                .from("fuel_logs")
                .insert(newLog)
                .execute()
                
            dismiss()
        } catch {
            uploadTaskError = error.localizedDescription
        }
    }
}

// VisionKit Scanner Wrapper
struct ReceiptScanner: UIViewControllerRepresentable {
    @Binding var scannedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ReceiptScanner

        init(_ parent: ReceiptScanner) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                parent.scannedImage = scan.imageOfPage(at: 0)
            }
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}
