import SwiftUI
import Combine
import UniformTypeIdentifiers
import AVFoundation
import Photos

struct VehicleDetailView: View {
    let vehicle: Vehicle
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm: VehicleDetailViewModel
    
    @State private var isEditing = false
    @State private var draftVehicle: Vehicle?
    @State private var isSaving = false
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isImportingDocument = false
    @State private var activeDocumentType: String?
    @State private var showStaffSelection = false
    
    // State for the Image Selection Pop-up
    @State private var showImageSourceDialog = false
    @State private var showReportsSheet = false
    
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _vm = StateObject(wrappedValue: VehicleDetailViewModel(initialVehicle: vehicle))
    }
    
    var body: some View {
        Form {
            if vm.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading Vehicle Details...")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let currentVehicle = vm.vehicle {
                
                // MARK: - Header Image Section
                Section {
                    vehicleImage(currentVehicle)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .frame(height: 200)
                }
                .listRowBackground(Color.clear)
                
                // MARK: - Vehicle Identification
                Section(header: Text("Vehicle Identification")) {
                    InfoRow(title: "Name", value: currentVehicle.name, isEditing: isEditing, text: binding(\.name))
                    
                    // Plate with auto-capitalization
                    InfoRow(title: "Plate", value: currentVehicle.registrationNumber, isEditing: isEditing, text: binding(\.registrationNumber))
                        .textCase(.uppercase)
                }
                
                // MARK: - Basic Info
                Section(header: Text("Basic Info")) {
                    InfoRow(title: "Brand", value: currentVehicle.brand ?? "—", isEditing: isEditing, text: binding(\.brand))
                    InfoRow(title: "Model", value: currentVehicle.model ?? "—", isEditing: isEditing, text: binding(\.model))
                    InfoRow(title: "Year", value: currentVehicle.modelYear ?? "—", isEditing: isEditing, text: binding(\.modelYear))
                    InfoRow(title: "Fuel", value: currentVehicle.fuelType ?? "—", isEditing: isEditing, text: binding(\.fuelType))
                }
                
                // MARK: - Registration Details
                Section(header: Text("Registration Details")) {
                    if isEditing {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("VIN")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(.systemGray2))
                            
                            TextField("Enter 17-digit VIN", text: binding(\.vin))
                                .textInputAutocapitalization(.characters)
                                .disableAutocorrection(true)
                                .onChange(of: draftVehicle?.vin) { _, newValue in
                                    if let val = newValue, val.count > 17 {
                                        draftVehicle?.vin = String(val.prefix(17))
                                    }
                                }
                            
                            if let vin = draftVehicle?.vin, !vin.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: vin.count == 17 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                    Text(vin.count == 17 ? "Valid VIN" : "Incomplete VIN")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(vin.count == 17 ? .green : .red)
                            }
                        }
                    } else {
                        InfoRow(title: "VIN", value: currentVehicle.vin.isEmpty ? "—" : currentVehicle.vin, isEditing: false, text: nil)
                    }
                    
                    InfoRow(title: "RC Number", value: currentVehicle.rcNumber.isEmpty ? "—" : currentVehicle.rcNumber, isEditing: isEditing, text: binding(\.rcNumber))
                    InfoRow(title: "Reg. Date", value: currentVehicle.registrationDate.isEmpty ? "—" : currentVehicle.registrationDate, isEditing: isEditing, text: binding(\.registrationDate))
                    InfoRow(title: "RC Expiry", value: currentVehicle.rcExpiryDate.isEmpty ? "—" : currentVehicle.rcExpiryDate, isEditing: isEditing, text: binding(\.rcExpiryDate))
                    InfoRow(title: "PUC Expiry", value: currentVehicle.pucExpiryDate.isEmpty ? "—" : currentVehicle.pucExpiryDate, isEditing: isEditing, text: binding(\.pucExpiryDate))
                }
                
                // MARK: - Documents
                Section(header: Text("Required Documents")) {
                    let requiredTypes = ["RC", "INSURANCE", "PUC"]
                    ForEach(requiredTypes, id: \.self) { type in
                        documentRowLogic(for: type)
                    }
                }
                
                // MARK: - Maintenance & Actions
                Section(header: Text("Actions")) {
                    Button {
                        showStaffSelection = true
                    } label: {
                        Label("Schedule Maintenance", systemImage: "wrench.and.screwdriver.fill")
                            .foregroundColor(.orange)
                    }
                    
                    Button {
                        showReportsSheet = true
                    } label: {
                        Label("View Reports", systemImage: "chart.bar.doc.horizontal.fill")
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Vehicle" : (vm.vehicle?.name ?? "Vehicle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                        draftVehicle = nil
                    }
                } else {
                    Button("Close") { dismiss() }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        Task { await saveChanges() }
                    }
                    .fontWeight(.bold)
                    // Disable save if VIN is not exactly 17 digits
                    .disabled(isSaving || (draftVehicle?.vin.count ?? 0) != 17)
                } else {
                    Button("Edit") {
                        draftVehicle = vm.vehicle
                        isEditing = true
                    }
                }
            }
        }
        .task {
            await vm.fetchVehicle(vehicleId: vehicle.id)
            await vm.fetchMaintenanceReports(vehicleId: vehicle.id)
        }
        .refreshable {
            await vm.fetchVehicle(vehicleId: vehicle.id)
            await vm.fetchMaintenanceReports(vehicleId: vehicle.id)
        }
        .sheet(isPresented: $showStaffSelection) {
            if let v = vm.vehicle { MaintenanceStaffPickerView(vehicle: v) }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: sourceType) { image in
                Task {
                    await vm.uploadImage(image: image, type: "VEHICLE")
                    if let newURL = vm.vehicle?.imageURL { draftVehicle?.imageURL = newURL }
                }
            }
        }
        // ✅ CORRECTED: fileImporter closure is attached properly
        .fileImporter(
            isPresented: $isImportingDocument,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first, let type = activeDocumentType {
                Task { await vm.uploadDocument(fileURL: url, type: type) }
            }
        }
        // ✅ CORRECTED: sheet is placed after the fileImporter completion block
        .sheet(isPresented: $showReportsSheet) {
            VehicleReportsListView(reports: vm.maintenanceReports)
        }
    }
    
    // MARK: - Subcomponents
    
    private func vehicleImage(_ vehicle: Vehicle) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let urlString = vehicle.imageURL, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                            .overlay(Image(systemName: vehicle.imageSystemName).font(.largeTitle).foregroundColor(.gray))
                    }
                } else {
                    Rectangle().fill(Color(.systemGray5))
                        .overlay(Image(systemName: vehicle.imageSystemName).font(.largeTitle).foregroundColor(.gray))
                }
            }
            .frame(height: 200)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                if isEditing { showImageSourceDialog = true }
            }
            
            if isEditing {
                Image(systemName: "camera.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 40))
                    .background(Circle().fill(.white))
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .confirmationDialog("Change Vehicle Photo", isPresented: $showImageSourceDialog) {
            Button("Take Photo") {
                handleCameraAccess {
                    sourceType = .camera
                    showImagePicker = true
                }
            }
            Button("Choose from Library") {
                handlePhotoLibraryAccess {
                    sourceType = .photoLibrary
                    showImagePicker = true
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    @ViewBuilder
    private func documentRowLogic(for type: String) -> some View {
        let doc = vm.documents.first(where: { $0.type.uppercased() == type })
        
        if isEditing {
            Button {
                activeDocumentType = type
                isImportingDocument = true
            } label: {
                HStack {
                    Text(type)
                    Spacer()
                    Text(doc == nil ? "Upload" : "Replace")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        } else if let doc = doc {
            if let url = URL(string: doc.fileURL) {
                Link(destination: url) {
                    Label(type, systemImage: "doc.text.fill")
                }
            }
        } else {
            HStack {
                Text(type)
                Spacer()
                Text("Missing").font(.caption).foregroundColor(.secondary)
            }
        }
    }
    
    private func saveChanges() async {
        guard let draft = draftVehicle else { return }
        vm.vehicle = draft
        isEditing = false
        draftVehicle = nil
        isSaving = true
        let success = await vm.updateVehicle()
        if success { await vm.fetchVehicle(vehicleId: vehicle.id) }
        isSaving = false
    }
    
    // MARK: - Helpers
    private func binding(_ keyPath: WritableKeyPath<Vehicle, String>) -> Binding<String> {
        Binding(get: { draftVehicle?[keyPath: keyPath] ?? "" }, set: { draftVehicle?[keyPath: keyPath] = $0 })
    }
    
    private func binding(_ keyPath: WritableKeyPath<Vehicle, String?>) -> Binding<String> {
        Binding(get: { draftVehicle?[keyPath: keyPath] ?? "" }, set: { draftVehicle?[keyPath: keyPath] = $0.isEmpty ? nil : $0 })
    }
    
    private func handleCameraAccess(onGranted: @escaping () -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized { onGranted() }
        else {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { DispatchQueue.main.async { onGranted() } }
            }
        }
    }
    
    private func handlePhotoLibraryAccess(onGranted: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited { onGranted() }
        else {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized || status == .limited {
                    DispatchQueue.main.async { onGranted() }
                }
            }
        }
    }
}

// MARK: - Row Component
struct InfoRow: View {
    let title: String
    let value: String
    var isEditing: Bool = false
    var text: Binding<String>? = nil
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isEditing, let text {
                TextField(title, text: text)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.blue)
                    .autocorrectionDisabled()
            } else {
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Dedicated Reports List View
struct VehicleReportsListView: View {
    let reports: [WorkOrderReportRecord]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if reports.isEmpty {
                    Text("No completed maintenance reports yet.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .padding()
                } else {
                    ForEach(reports) { report in
                        if let url = URL(string: report.reportUrl) {
                            Link(destination: url) {
                                HStack(spacing: 16) {
                                    Image(systemName: "doc.viewfinder.fill")
                                        .foregroundColor(.red)
                                        .font(.title)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(report.reportName ?? "Completion Report")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Work Order #WO-\(report.workOrderId.uuidString.prefix(6).uppercased())")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Maintenance Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
