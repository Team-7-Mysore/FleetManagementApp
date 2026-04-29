import SwiftUI
import Combine
import UniformTypeIdentifiers
import AVFoundation
import Photos


private enum DetailViewCache {
    static let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

struct VehicleDetailView: View {
    let vehicle: Vehicle
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm: VehicleDetailViewModel
    
    @State private var showSourcePopover = false
    @State private var isEditing = false
    @State private var draftVehicle: Vehicle?
    @State private var isSaving = false
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isImportingDocument = false
    @State private var activeDocumentType: String?
    @State private var showStaffSelection = false
    @State private var showImageSourceDialog = false
    @State private var showReportsSheet = false
    @State private var usageReportURL: URL?
    @State private var showUsageReportPreview = false
    
    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _vm = StateObject(wrappedValue: VehicleDetailViewModel(initialVehicle: vehicle))
    }
    
    var body: some View {
        Form {
            if vm.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let currentVehicle = vm.vehicle {
                
            
                Section {
                    vehicleImage(currentVehicle)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .frame(height: 200)
                }
                .listRowBackground(Color.clear)
                
          
                Section(header: Text("Required Documents")) {
                    let requiredTypes = ["RC", "INSURANCE", "PUC"]
                    ForEach(requiredTypes, id: \.self) { type in
                        documentRowLogic(for: type)
                    }
                }
                
            
                Section(header: Text("Vehicle Identification")) {
                    InfoRow(title: "Name", value: currentVehicle.name, isEditing: isEditing, text: binding(\.name))
                    InfoRow(title: "Plate", value: currentVehicle.registrationNumber, isEditing: false, text: nil)
                        .textCase(.uppercase)
                }
                
          
                Section(header: Text("Basic Info")) {
                    InfoRow(title: "Brand", value: currentVehicle.brand ?? "—", isEditing: false, text: nil)
                    InfoRow(title: "Model", value: currentVehicle.model ?? "—", isEditing: false, text: nil)
                    InfoRow(title: "Year", value: currentVehicle.modelYear ?? "—", isEditing: false, text: nil)
                    InfoRow(title: "Fuel", value: currentVehicle.fuelType ?? "—", isEditing: false, text: nil)
                    if isEditing {
                        Toggle("SDV Enabled", isOn: $vm.isSdvsEnabled)
                    } else {
                        HStack {
                            Text("SDV Enabled")
                            Spacer()
                            Text(currentVehicle.isSdvsEnabled ? "Yes" : "No")
                                .foregroundColor(currentVehicle.isSdvsEnabled ? .orange : .primary)
                        }
                    }
                }
                
                
                Section(header: Text("Registration Details")) {
                    InfoRow(title: "VIN", value: currentVehicle.vin.isEmpty ? "—" : currentVehicle.vin, isEditing: false, text: nil)
                    
                    // Note: RC Number removed as requested
                    InfoRow(title: "Reg. Date", value: currentVehicle.registrationDate.isEmpty ? "—" : currentVehicle.registrationDate, isEditing: isEditing, text: binding(\.registrationDate))
                    InfoRow(title: "RC Expiry", value: currentVehicle.rcExpiryDate.isEmpty ? "—" : currentVehicle.rcExpiryDate, isEditing: isEditing, text: binding(\.rcExpiryDate))
                    InfoRow(title: "PUC Expiry", value: currentVehicle.pucExpiryDate.isEmpty ? "—" : currentVehicle.pucExpiryDate, isEditing: isEditing, text: binding(\.pucExpiryDate))
                }
                
               
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
                        Label("Maintaince Reports", systemImage: "chart.bar.doc.horizontal.fill")
                            .foregroundColor(.purple)
                    }
                    Button {
                        Task { await createVehicleUsageReport() }
                    } label: {
                        if vm.isGeneratingUsageReport {
                            HStack {
                                ProgressView()
                                Text("Generating Usage Report...")
                            }
                        } else {
                            Label("Vehicle Usage Reports", systemImage: "fuelpump.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(vm.isGeneratingUsageReport)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Vehicle" : (vm.vehicle?.name ?? "Vehicle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Cancel") { isEditing = false; draftVehicle = nil }
                } else {
                    Button("Close") { dismiss() }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") { Task { await saveChanges() } }
                        .fontWeight(.bold)
                        .disabled(isSaving)
                } else {
                    Button("Edit") { draftVehicle = vm.vehicle; isEditing = true }
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
        .fileImporter(
            isPresented: $isImportingDocument,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first, let type = activeDocumentType {
                Task { await vm.uploadDocument(fileURL: url, type: type) }
            }
        }
        .sheet(isPresented: $showReportsSheet) {
            VehicleReportsListView(reports: vm.maintenanceReports)
        }
        .sheet(isPresented: $showUsageReportPreview) {
            if let usageReportURL {
                PDFPreviewSheet(fileURL: usageReportURL)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: sourceType) { image in
                Task {
                    if let type = activeDocumentType {
                        await vm.uploadImage(image: image, type: type)
                        if type == "RC" {
                            await vm.processVehicleOCR(from: image)
                            if isEditing { draftVehicle = vm.vehicle }
                        }
                        activeDocumentType = nil
                    } else {
                        await vm.uploadImage(image: image, type: "VEHICLE")
                        if let newURL = vm.vehicle?.imageURL { draftVehicle?.imageURL = newURL }
                    }
                }
            } onPDFPicked: { pdfURL in
                Task {
                    if let type = activeDocumentType {
                        await vm.uploadDocument(fileURL: pdfURL, type: type)
                        if type == "RC" {
                            await vm.processVehicleOCR(from: pdfURL)
                            if isEditing { draftVehicle = vm.vehicle }
                        }
                        activeDocumentType = nil
                    }
                }
            }
        }
        .alert("Something Went Wrong", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.errorMessage ?? "Unknown error")
        }
    }
    
  
    
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
            .onTapGesture { if isEditing { showImageSourceDialog = true } }
            
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
            Button("Take Photo") { handleCameraAccess { sourceType = .camera; showImagePicker = true } }
            Button("Choose from Library") { handlePhotoLibraryAccess { sourceType = .photoLibrary; showImagePicker = true } }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    @ViewBuilder
    private func documentRowLogic(for type: String) -> some View {
        let doc = vm.documents.first(where: { $0.type.uppercased() == type })
        
        let expiryDateStr: String? = {
            switch type.uppercased() {
            case "RC": return vm.vehicle?.rcExpiryDate
            case "INSURANCE": return "2027-01-01"
            case "PUC": return vm.vehicle?.pucExpiryDate
            default: return nil
            }
        }()
        
        let isExpired: Bool = {
            guard let dateStr = expiryDateStr, !dateStr.isEmpty,
                  let date = DetailViewCache.formatter.date(from: dateStr) else { return false }
            return date < Date()
        }()

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(type).font(.system(size: 16, weight: .bold))
                if let fileName = doc?.fileName {
                    Text(fileName).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if doc != nil {
                    Text(isExpired ? "Expired" : "Valid")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(isExpired ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                        .foregroundColor(isExpired ? .red : .green)
                        .clipShape(Capsule())
                } else {
                    Text("No Document")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.gray)
                        .clipShape(Capsule())
                }
                
                if isEditing {
                    Button(doc == nil ? "Upload" : "Replace") {
                        activeDocumentType = type
                        showSourcePopover = true
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
                    .popover(isPresented: Binding(
                        get: { showSourcePopover && activeDocumentType == type },
                        set: { if !$0 { showSourcePopover = false } }
                    )) {
                        VStack(alignment: .leading, spacing: 0) {
                            popoverButton(title: "Camera", icon: "camera") { sourceType = .camera; showImagePicker = true }
                            Divider()
                            popoverButton(title: "Gallery", icon: "photo.on.rectangle") { sourceType = .photoLibrary; showImagePicker = true }
                            Divider()
                            popoverButton(title: "Files", icon: "folder") { isImportingDocument = true }
                        }
                        .presentationCompactAdaptation(.popover)
                        .frame(width: 200).padding(.vertical, 8)
                    }
                } else if doc != nil {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Lazy load: fetch document URL when user taps (if not already fetched)
            guard !isEditing, let doc = doc, let vehicleId = vm.vehicle?.id else { return }
            
            if doc.fileURL.isEmpty {
                Task {
                    if let url = await vm.fetchDocumentURL(for: type, vehicleId: vehicleId) {
                        await MainActor.run {
                            vm.setDocumentURL(url, for: type)
                            if let openedURL = URL(string: url) {
                                UIApplication.shared.open(openedURL)
                            }
                        }
                    }
                }
            } else if doc.fileURL.count > 5, let url = URL(string: doc.fileURL) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func popoverButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button { showSourcePopover = false; action() } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
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

    private func createVehicleUsageReport() async {
        do {
            let result = try await vm.generateVehicleUsageReport()
            await MainActor.run {
                usageReportURL = result.localURL
                showUsageReportPreview = true
            }
        } catch {
            await MainActor.run {
                vm.errorMessage = error.localizedDescription
            }
        }
    }
    
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
                Text(value).foregroundColor(.secondary)
            }
        }
    }
}

struct VehicleReportsListView: View {
    let reports: [WorkOrderReportRecord]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if reports.isEmpty {
                    Text("No completed maintenance reports yet.").foregroundColor(.secondary).font(.subheadline).padding()
                } else {
                    ForEach(reports) { report in
                        if let url = URL(string: report.reportUrl) {
                            Link(destination: url) {
                                HStack(spacing: 16) {
                                    Image(systemName: "doc.viewfinder.fill").foregroundColor(.red).font(.title)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(report.reportName ?? "Completion Report").font(.headline).foregroundColor(.primary)
                                        Text("Work Order #WO-\(report.workOrderId.uuidString.prefix(6).uppercased())").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption)
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
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }
}
