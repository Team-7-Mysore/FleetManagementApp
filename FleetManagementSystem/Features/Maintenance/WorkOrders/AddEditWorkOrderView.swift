import SwiftUI
import Supabase

// Lightweight UI model for parts
struct PartSelectionUI: Identifiable {
    let id = UUID()
    var inventoryId: UUID
    var name: String
    var quantity: Int
}

private struct WorkOrderVehicleFetch: Decodable, Identifiable {
    var id: UUID { vehicle_id }
    let vehicle_id: UUID
    let vehicle_name: String
    let vin: String?
    let number_plate: String?
    let vehicle_type: String?
}

struct AddEditWorkOrderView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel Injection
    @StateObject private var viewModel = WorkOrderViewModel()
    @State private var activeUserId: UUID? = nil
    
    // MARK: - State Variables
    // Using our local struct here so it doesn't mess with the rest of your app
    @State private var availableVehicles: [WorkOrderVehicleFetch] = []
    @State private var selectedVehicleId: UUID? = nil
    
    // Vehicle Text Fields (Auto-filled & Read-Only)
    @State private var vehicleName: String = ""
    @State private var vin: String = ""
    @State private var numberPlate: String = ""
    @State private var vehicleType: VehicleType = .car // For the dynamic image
    
    @State private var issueTitle: String = ""
    @State private var issueDescription: String = ""
    
    // Tasks State
    @State private var tasks: [String] = []
    @State private var newTaskName: String = ""
    
    // Parts State
    @State private var parts: [PartSelectionUI] = []
    
    // Photos State
    @State private var photos: [String] = []
    @State private var showImagePicker: Bool = false
    
    @State private var priority: WorkOrderPriority = .medium
    @State private var internalNotes: String = ""
    
    // Saving State
    @State private var isSaving: Bool = false
    
    // Routing / Autofill Data
    var sourceIssueId: UUID?
    var managerId: UUID?
    var preSelectedVehicleId: UUID?
    var prefilledSummary: String?
    var prefilledDescription: String?
    var maintenancePersonnelId: UUID?
    
    // Custom Initializer
    init(sourceIssueId: UUID? = nil, preSelectedVehicleId: UUID? = nil, prefilledSummary: String? = nil, prefilledDescription: String? = nil, managerId: UUID? = nil, maintenancePersonnelId: UUID? = nil) {
        self.sourceIssueId = sourceIssueId
        self.managerId = managerId
        self.preSelectedVehicleId = preSelectedVehicleId
        self.prefilledSummary = prefilledSummary
        self.prefilledDescription = prefilledDescription
        self.maintenancePersonnelId = maintenancePersonnelId // Assign it here
    }
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    vehicleIdentificationSection
                    issueSummarySection
                    taskChecklistSection
                    partsRequiredSection
                    photoDocumentationSection
                    priorityAndNotesSection
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                if let imageData = image.jpegData(compressionQuality: 0.7) {
                    let filename = UUID().uuidString + ".jpg"
                    Task {
                        do {
                            let uploadedImageUrl = try await viewModel.uploadImageToSupabase(imageData: imageData, fileName: filename)
                            await MainActor.run { photos.append(uploadedImageUrl) }
                        } catch {
                            print("Failed to upload image: \(error)")
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.fetchAllInventory()
            await fetchVehicles()
            if let desc = prefilledDescription, !desc.isEmpty {
                self.issueDescription = desc
            }
        }
        .task {
            // Fetch the user ID safely when the screen actually opens
            do {
                let user = try await SupabaseManager.shared.client.auth.user()
                self.activeUserId = user.id
                print("🎯 Active User ID grabbed successfully: \(user.id)")
            } catch {
                print("⚠️ Failed to grab user ID on load: \(error)")
            }
        }
        .navigationTitle("New Work Order")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveWorkOrderToSupabase()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save").fontWeight(.semibold)
                    }
                }
                .disabled(isSaving || selectedVehicleId == nil)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.bold)
            }
        }
    }
    
    // MARK: - UI Sections (Chunked for fast compiling)
    
    private var vehicleIdentificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "VEHICLE IDENTIFICATION")
            CardView {
                VStack(spacing: 16) {
                    
                    // Clean Dropdown Row
                    if availableVehicles.isEmpty {
                        ProgressView("Loading vehicles...")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack {
                            Text("Select Vehicle")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Picker("Select Vehicle", selection: $selectedVehicleId) {
                                Text("Choose...").tag(UUID?.none)
                                ForEach(availableVehicles, id: \.id) { vehicle in
                                    Text(vehicle.vehicle_name).tag(UUID?.some(vehicle.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.blue)
                        }
                        .onChange(of: selectedVehicleId) { newId in
                            updateVehicleDetails(for: newId)
                        }
                    }
                    
                    Divider()
                    
                    // Visible Auto-filled Data Fields
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: vehicleType.sfSymbol)
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 54, height: 54)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        
                        VStack(spacing: 12) {
                            TextField("Vehicle Name", text: .constant(vehicleName.isEmpty ? "No Vehicle Selected" : vehicleName))
                                .font(.subheadline)
                                .foregroundColor(vehicleName.isEmpty ? .gray : .primary)
                                .disabled(true)
                            
                            Divider()
                            
                            TextField("VIN", text: .constant(vin.isEmpty ? "N/A" : vin))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .disabled(true)
                            
                            Divider()
                            
                            TextField("Number Plate", text: .constant(numberPlate.isEmpty ? "N/A" : numberPlate))
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .disabled(true)
                        }
                    }
                }
            }
        }
    }
    
    private var issueSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "ISSUE SUMMARY")
            CardView {
                VStack(spacing: 12) {
                    TextField("Short Description (e.g. Engine noise)", text: $issueTitle)
                        .font(.subheadline)
                    Divider()
                    TextField("Detailed symptoms or notes...", text: $issueDescription, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(3...6)
                }
            }
        }
    }
    
    private var taskChecklistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "TASK CHECKLIST")
            CardView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(tasks, id: \.self) { task in
                        HStack {
                            Image(systemName: "circle.grid.2x2.fill").foregroundColor(Color(uiColor: .systemGray4)).font(.caption)
                            Text(task).font(.subheadline)
                            Spacer()
                            Button(action: { tasks.removeAll { $0 == task } }) {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red.opacity(0.8))
                            }
                        }
                        Divider()
                    }
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                        TextField("Add new task...", text: $newTaskName)
                            .font(.subheadline)
                            .onSubmit {
                                guard !newTaskName.isEmpty else { return }
                                tasks.append(newTaskName)
                                newTaskName = ""
                            }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var partsRequiredSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "PARTS REQUIRED")
            CardView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach($parts) { $part in
                        HStack {
                            Text(part.name).font(.subheadline).fontWeight(.medium)
                            Spacer()
                            HStack(spacing: 16) {
                                Button(action: { if part.quantity > 1 { part.quantity -= 1 } }) { Image(systemName: "minus").foregroundColor(.blue) }
                                Text("\(part.quantity)").font(.subheadline).fontWeight(.medium)
                                Button(action: { part.quantity += 1 }) { Image(systemName: "plus").foregroundColor(.blue) }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8).background(Color(uiColor: .systemGray6)).cornerRadius(8)
                            Button(action: { parts.removeAll { $0.id == part.id } }) { Image(systemName: "trash.fill").foregroundColor(.red.opacity(0.8)) }
                                .padding(.leading, 8)
                        }
                        Divider()
                    }
                    Menu {
                        if viewModel.availableInventory.isEmpty {
                            Text("Loading inventory...")
                        } else {
                            ForEach(viewModel.availableInventory) { item in
                                Button {
                                    if !parts.contains(where: { $0.inventoryId == item.inventoryId }) {
                                        parts.append(PartSelectionUI(inventoryId: item.inventoryId, name: item.partName, quantity: 1))
                                    }
                                } label: { Text("\(item.partName) (In Stock: \(item.quantity))") }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                            Text("Select a Part from Inventory...").font(.subheadline).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
    
    private var photoDocumentationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "PHOTO DOCUMENTATION")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    Button(action: { showImagePicker = true }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .systemGray5)).frame(width: 110, height: 110)
                            Image(systemName: "plus").font(.system(size: 32, weight: .semibold)).foregroundColor(.blue)
                        }
                    }
                    .padding(.leading, 1)
                    
                    ForEach(photos, id: \.self) { photoUrlString in
                        ZStack(alignment: .topTrailing) {
                            RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .systemGray6)).frame(width: 110, height: 110)
                            if let url = URL(string: photoUrlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty: ProgressView()
                                    case .success(let image): image.resizable().scaledToFill().frame(width: 110, height: 110).clipShape(RoundedRectangle(cornerRadius: 16))
                                    case .failure: Image(systemName: "exclamationmark.triangle").foregroundColor(.red)
                                    @unknown default: EmptyView()
                                    }
                                }
                            }
                            Button(action: { photos.removeAll { $0 == photoUrlString } }) {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red).background(Circle().fill(Color.white)).font(.system(size: 22))
                            }
                            .offset(x: 10, y: -10)
                        }
                    }
                }
                .padding(.top, 10).padding(.horizontal, 16)
            }
        }
    }
    
    private var priorityAndNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "PRIORITY LEVEL")
            CardView {
                HStack {
                    Text("Priority").font(.subheadline)
                    Spacer()
                    Picker("Priority", selection: $priority) {
                        ForEach(WorkOrderPriority.allCases, id: \.self) { p in Text(p.rawValue).tag(p) }
                    }
                    .pickerStyle(.menu).tint(.primary)
                }
            }
            
            SectionHeaderView(title: "INTERNAL NOTES")
                .padding(.top, 16)
            CardView {
                TextField("Additional details only visible to mechanics...", text: $internalNotes, axis: .vertical)
                    .font(.subheadline).lineLimit(4...8)
            }
        }
    }
    
    // MARK: - Fetch & Update Logic
    
    private func fetchVehicles() async {
        do {
            // Using the local struct so your global VehicleDTO stays safe!
            let fetched: [WorkOrderVehicleFetch] = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("vehicle_id, vehicle_name, vin, number_plate, vehicle_type")
                .execute()
                .value
            
            await MainActor.run {
                self.availableVehicles = fetched
                
                // If coming from a notification, auto-fill everything!
                if let vId = preSelectedVehicleId {
                    self.selectedVehicleId = vId
                    updateVehicleDetails(for: vId)
                }
                if let summary = prefilledSummary, !summary.isEmpty {
                    self.issueTitle = summary
                }
            }
        } catch {
            print("🚨 Error fetching vehicles: \(error)")
        }
    }
    
    private func updateVehicleDetails(for id: UUID?) {
        if let selected = availableVehicles.first(where: { $0.id == id }) {
            self.vehicleName = selected.vehicle_name
            self.vin = selected.vin ?? ""
            self.numberPlate = selected.number_plate ?? ""
            
            // DYNAMIC IMAGE LOGIC
            if let dbType = selected.vehicle_type,
               let matchedType = VehicleType.allCases.first(where: { $0.rawValue.lowercased() == dbType.lowercased() }) {
                self.vehicleType = matchedType
            } else {
                self.vehicleType = .car
            }
        } else {
            self.vehicleName = ""
            self.vin = ""
            self.numberPlate = ""
            self.vehicleType = .car
        }
    }
    
    // MARK: - ViewModel Saving Logic
    private func saveWorkOrderToSupabase() {
        guard !isSaving else { return }
        guard let finalVehicleId = selectedVehicleId else { return }
        
        isSaving = true
        
        Task {
            do {
                let newWorkOrderId = UUID()
                
                print("--- PRE-SAVE DEBUG ---")
                print("Maintenance ID: \(String(describing: self.maintenancePersonnelId))")
                
                let newOrder = WorkOrder(
                    workOrderId: newWorkOrderId,
                    vehicleId: finalVehicleId,
                    maintenancePersonnelId: self.activeUserId ?? self.maintenancePersonnelId,
                    vehicle: nil,
                    priority: priority,
                    status: .pending,
                    isApproved: false,
                    issueTitle: issueTitle.isEmpty ? "No Title Provided" : issueTitle,
                    issueDescription: issueDescription.isEmpty ? nil : issueDescription,
                    hoursWorked: 0.0,
                    estCost: 0.0,
                    internalNotes: internalNotes.isEmpty ? nil : internalNotes,
                    maintenanceNotes: nil,
                    images: photos.isEmpty ? nil : photos,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                let workOrderTasks = tasks.map { taskName in
                    WorkOrderTask(
                        taskId: UUID(),
                        workOrderId: newWorkOrderId,
                        description: taskName,
                        isCompleted: false,
                        createdAt: Date()
                    )
                }
                
                let workOrderParts = parts.map { uiPart in
                    WorkOrderPart(
                        workOrderId: newWorkOrderId,
                        inventoryId: uiPart.inventoryId,
                        quantityRequired: uiPart.quantity,
                        costAtTime: nil
                    )
                }
                
                // 2. Push to Supabase
                try await viewModel.upsertWorkOrder(newOrder)
                try await viewModel.insertTasks(workOrderTasks)
                try await viewModel.upsertParts(workOrderParts)
                
                // 3. Update the manager's issue status
                if let issueIdToUpdate = self.sourceIssueId {
                    struct IssueUpdate: Encodable { let status: String }
                    try await SupabaseManager.shared.client
                        .from("maintenance_issues")
                        .update(IssueUpdate(status: "in_progress"))
                        .eq("issue_id", value: issueIdToUpdate.uuidString)
                        .execute()
                }
                
                // 4. Send Approval Notification back to the Manager
                if let actualManagerId = self.managerId {
                    // Fetch the logged in personnel's ID to set as sender
                    let session = try await SupabaseManager.shared.client.auth.session
                    let currentUserId = session.user.id
                    
                    let approvalNotification = NotificationInsertDTO(
                        recipient_id: actualManagerId,
                        sender_id: currentUserId, 
                        title: "Approval Required",
                        message: "Work Order '\(issueTitle)' requires your approval.",
                        type: NotificationType.maintenance.rawValue,
                        related_entity_id: newWorkOrderId
                    )
                    
                    try await SupabaseManager.shared.client
                        .from("notifications")
                        .insert(approvalNotification)
                        .execute()
                }
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
                
            } catch {
                print("🚨 Error saving work order: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}



#Preview {
    NavigationStack {
        AddEditWorkOrderView()
    }
}
