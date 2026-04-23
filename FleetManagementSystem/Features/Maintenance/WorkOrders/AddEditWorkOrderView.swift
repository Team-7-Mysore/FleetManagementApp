import SwiftUI
import Supabase

// Lightweight UI model for parts while filling out the form
struct PartSelectionUI: Identifiable {
    let id = UUID()
    var inventoryId: UUID // Needed for the database mapping
    var name: String
    var quantity: Int
}

struct AddEditWorkOrderView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModel Injection
    @StateObject private var viewModel = WorkOrderViewModel()
    
    // MARK: - State Variables
    @State private var vin: String = ""
    @State private var fleetId: String = ""
    @State private var vehicleName: String = ""
    @State private var vehicleType: VehicleType = .car
    
    @State private var issueTitle: String = ""
    @State private var issueDescription: String = ""
    
    // Tasks State
    @State private var tasks: [String] = []
    @State private var newTaskName: String = ""
    
    // Parts State
    @State private var parts: [PartSelectionUI] = []
    
    // Photos State
    @State private var photos: [String] = []
    @State private var showImagePicker: Bool = false // <-- Added state for image picker
    
    @State private var priority: WorkOrderPriority = .medium
    @State private var internalNotes: String = ""
    
    // Saving State
    @State private var isSaving: Bool = false
    @State private var selectedVehicleId: UUID? = nil
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: 1. Vehicle Identification
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "VEHICLE IDENTIFICATION")
                        
                        CardView {
                            VStack(spacing: 12) {
                                HStack(alignment: .top, spacing: 16) {
                                    // Dynamic Vehicle Icon
                                    Image(systemName: vehicleType.sfSymbol)
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .frame(width: 54, height: 54)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(12)
                                    
                                    VStack(spacing: 12) {
                                        TextField("VIN", text: $vin)
                                            .font(.subheadline)
                                        Divider()
                                        TextField("Fleet ID", text: $fleetId)
                                            .font(.subheadline)
                                        Divider()
                                        TextField("Vehicle Name", text: $vehicleName)
                                            .font(.subheadline)
                                    }
                                }
                                
                                Divider().padding(.vertical, 4)
                                
                                // Vehicle Type Dropdown
                                HStack {
                                    Text("Vehicle Type")
                                        .font(.subheadline)
                                    Spacer()
                                    Picker("Vehicle Type", selection: $vehicleType) {
                                        ForEach(VehicleType.allCases, id: \.self) { type in
                                            Text(type.rawValue).tag(type)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.primary)
                                }
                            }
                        }
                    }
                    
                    // MARK: 2. Issue Summary
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
                    
                    // MARK: 3. Task Checklist
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "TASK CHECKLIST")
                        
                        CardView {
                            VStack(alignment: .leading, spacing: 16) {
                                // Render added tasks
                                ForEach(tasks, id: \.self) { task in
                                    HStack {
                                        Image(systemName: "circle.grid.2x2.fill")
                                            .foregroundColor(Color(uiColor: .systemGray4))
                                            .font(.caption)
                                        Text(task)
                                            .font(.subheadline)
                                        Spacer()
                                        Button(action: {
                                            tasks.removeAll { $0 == task }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red.opacity(0.8))
                                        }
                                    }
                                    Divider()
                                }
                                
                                // Full-width inline task adder
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                    
                                    TextField("Add new task...", text: $newTaskName)
                                        .font(.subheadline)
                                        .onSubmit {
                                            guard !newTaskName.isEmpty else { return }
                                            tasks.append(newTaskName)
                                            newTaskName = "" // Reset field
                                        }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    // MARK: 4. Parts Required
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "PARTS REQUIRED")
                        
                        CardView {
                            VStack(alignment: .leading, spacing: 16) {
                                // Render added parts
                                ForEach($parts) { $part in
                                    HStack {
                                        Text(part.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Spacer()
                                        
                                        // Custom Stepper Look
                                        HStack(spacing: 16) {
                                            Button(action: {
                                                if part.quantity > 1 { part.quantity -= 1 }
                                            }) {
                                                Image(systemName: "minus")
                                                    .foregroundColor(.blue)
                                            }
                                            
                                            Text("\(part.quantity)")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Button(action: {
                                                part.quantity += 1
                                            }) {
                                                Image(systemName: "plus")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(uiColor: .systemGray6))
                                        .cornerRadius(8)
                                        
                                        // Remove part button
                                        Button(action: {
                                            parts.removeAll { $0.id == part.id }
                                        }) {
                                            Image(systemName: "trash.fill")
                                                .foregroundColor(.red.opacity(0.8))
                                        }
                                        .padding(.leading, 8)
                                    }
                                    Divider()
                                }
                                
                                // Full-width inline part adder (Dropdown Menu)
                                Menu {
                                    if viewModel.availableInventory.isEmpty {
                                        Text("Loading inventory...")
                                    } else {
                                        ForEach(viewModel.availableInventory) { item in
                                            Button {
                                                // Prevent adding duplicate parts
                                                if !parts.contains(where: { $0.inventoryId == item.inventoryId }) {
                                                    parts.append(
                                                        PartSelectionUI(
                                                            inventoryId: item.inventoryId,
                                                            name: item.partName,
                                                            quantity: 1
                                                        )
                                                    )
                                                }
                                            } label: {
                                                Text("\(item.partName) (In Stock: \(item.quantity))")
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                        
                                        Text("Select a Part from Inventory...")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                    
                    // MARK: 5. Photo Documentation
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeaderView(title: "PHOTO DOCUMENTATION")
                        
                        // Increased spacing for the larger images
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                
                                // 1. Add Photo Button (Moved to the BEGINNING)
                                Button(action: {
                                    showImagePicker = true
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(uiColor: .systemGray5)) // Grey placeholder background
                                            .frame(width: 110, height: 110) // Increased size to match your screenshot
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.leading, 1) // Clean alignment
                                
                                // 2. Uploaded Photos (Will appear AFTER the add button)
                                ForEach(photos, id: \.self) { photoUrlString in
                                    ZStack(alignment: .topTrailing) {
                                        
                                        // Placeholder / Background
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(uiColor: .systemGray6))
                                            .frame(width: 110, height: 110)
                                        
                                        // The actual picture loaded from the Supabase URL
                                        if let url = URL(string: photoUrlString) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView()
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 110, height: 110)
                                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                                case .failure:
                                                    Image(systemName: "exclamationmark.triangle")
                                                        .foregroundColor(.red)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                        }
                                        
                                        // DELETE BUTTON
                                        Button(action: {
                                            // TODO: Logic to delete the file from Supabase storage bucket can be added later
                                            // For now, we remove it from the local list
                                            photos.removeAll { $0 == photoUrlString }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Circle().fill(Color.white))
                                                .font(.system(size: 22))
                                        }
                                        .offset(x: 10, y: -10)
                                    }
                                }
                            }
                            // Add vertical padding so the delete buttons don't get clipped
                            .padding(.top, 10)
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // MARK: 6. Priority Level
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "PRIORITY LEVEL")
                        
                        CardView {
                            HStack {
                                Text("Priority")
                                    .font(.subheadline)
                                Spacer()
                                Picker("Priority", selection: $priority) {
                                    ForEach(WorkOrderPriority.allCases, id: \.self) { p in
                                        Text(p.rawValue).tag(p)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.primary)
                            }
                        }
                    }
                    
                    // MARK: 7. Internal Notes
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "INTERNAL NOTES")
                        
                        CardView {
                            TextField("Additional details only visible to mechanics...", text: $internalNotes, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(4...8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40) // Give bottom breathing room
            }
        }
        // MARK: - Image Picker Sheet
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                if let imageData = image.jpegData(compressionQuality: 0.7) {
                    let filename = UUID().uuidString + ".jpg"
                    
                    Task {
                        do {
                            let uploadedImageUrl = try await viewModel.uploadImageToSupabase(
                                imageData: imageData,
                                fileName: filename
                            )
                            
                            await MainActor.run {
                                photos.append(uploadedImageUrl)
                            }
                            
                            print("Image successfully uploaded to Bucket: \(uploadedImageUrl)")
                        } catch {
                            print("Failed to upload image: \(error)")
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.fetchAllInventory()
        }
        .navigationTitle("New Work Order")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#A3352A"))
                }
            }
            
            // Trailing Save Button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    saveWorkOrderToSupabase()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSaving)
            }
        }
        
        // MARK: - Keyboard Done Toolbar
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer() // Pushes the Done button to the right side
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.bold)
            }
        }
    }
    
    // MARK: - ViewModel Saving Logic
    private func saveWorkOrderToSupabase() {
        guard !isSaving else { return }
        isSaving = true
        
        Task {
            do {
                let newWorkOrderId = UUID()
                
                // NEW: Ensure you have the UUID of the selected vehicle in your view!
                // Assuming you have a variable like `selectedVehicleId: UUID`
                guard let vehicleId = selectedVehicleId else {
                    print("🚨 No vehicle selected!")
                    isSaving = false
                    return
                }
                
                // 1. The 'images: photos' line automatically maps your uploaded
                // bucket URLs directly into the 'images text[]' PostgreSQL column!
                let newOrder = WorkOrder(
                    workOrderId: newWorkOrderId,
                    
                    vehicleId: vehicleId, // <-- NEW: Strictly linking the ID
                    vehicle: nil,         // <-- NEW: We pass nil here because we don't need to upload the joined object back to the DB
                    
                    priority: priority,
                    status: .pending,
                    isApproved: false, // Wait for manager approval
                    issueTitle: issueTitle.isEmpty ? "No Title Provided" : issueTitle,
                    issueDescription: issueDescription.isEmpty ? nil : issueDescription,
                    hoursWorked: 0.0,
                    estCost: 0.0,
                    internalNotes: internalNotes.isEmpty ? nil : internalNotes,
                    maintenanceNotes: nil,
                    images: photos.isEmpty ? nil : photos, // <-- THIS DOES ALL THE MAGIC
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
                
                // 2. Push to Supabase (Images are saved as part of the WorkOrder!)
                try await viewModel.upsertWorkOrder(newOrder)
                try await viewModel.insertTasks(workOrderTasks)
                try await viewModel.upsertParts(workOrderParts)
                
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

