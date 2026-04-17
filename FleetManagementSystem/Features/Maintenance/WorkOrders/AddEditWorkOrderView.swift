import SwiftUI
import Supabase

// MARK: - Helper Extension
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

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
    @State private var newPartName: String = ""
    
    // Photos State
    @State private var photos: [String] = []
    
    @State private var priority: WorkOrderPriority = .medium
    @State private var internalNotes: String = ""
    
    // Saving State
    @State private var isSaving: Bool = false
    
    var body: some View {
        ZStack {
            // Background color dismisses keyboard
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: 1. Vehicle Identification
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "VEHICLE IDENTIFICATION")
                        
                        CardView {
                            VStack(spacing: 0) { // Changed spacing to 0 because text fields now have vertical padding
                                HStack(alignment: .top, spacing: 16) {
                                    // Dynamic Vehicle Icon
                                    Image(systemName: vehicleType.sfSymbol)
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .frame(width: 54, height: 54)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(12)
                                        .padding(.top, 10)
                                    
                                    VStack(spacing: 0) {
                                        // Expanded hit area for VIN
                                        TextField("VIN", text: $vin)
                                            .font(.subheadline)
                                            .padding(.vertical, 12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Divider()
                                        
                                        // Expanded hit area for Fleet ID
                                        TextField("Fleet ID", text: $fleetId)
                                            .font(.subheadline)
                                            .padding(.vertical, 12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Divider()
                                        
                                        // Expanded hit area for Vehicle Name
                                        TextField("Vehicle Name", text: $vehicleName)
                                            .font(.subheadline)
                                            .padding(.vertical, 12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
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
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    // MARK: 2. Issue Summary
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "ISSUE SUMMARY")
                        
                        CardView {
                            VStack(spacing: 0) {
                                TextField("Short Description (e.g. Engine noise)", text: $issueTitle)
                                    .font(.subheadline)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Divider()
                                
                                TextField("Detailed symptoms or notes...", text: $issueDescription, axis: .vertical)
                                    .font(.subheadline)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(3...6)
                            }
                        }
                    }
                    
                    // MARK: 3. Task Checklist
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "TASK CHECKLIST")
                        
                        CardView {
                            VStack(alignment: .leading, spacing: 8) {
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
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                                
                                // Full-width inline task adder
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                    
                                    TextField("Add Task...", text: $newTaskName)
                                        .font(.subheadline)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .onSubmit {
                                            guard !newTaskName.isEmpty else { return }
                                            tasks.append(newTaskName)
                                            newTaskName = "" // clear after adding
                                        }
                                }
                            }
                        }
                    }
                    
                    // MARK: 4. Parts Required
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "PARTS REQUIRED")
                        
                        CardView {
                            VStack(alignment: .leading, spacing: 8) {
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
                                    .padding(.vertical, 8)
                                    Divider()
                                }
                                
                                // Full-width inline part adder
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                    
                                    TextField("Add Part Name or SKU...", text: $newPartName)
                                        .font(.subheadline)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .onSubmit {
                                            guard !newPartName.isEmpty else { return }
                                            parts.append(PartSelectionUI(inventoryId: UUID(), name: newPartName, quantity: 1))
                                            newPartName = ""
                                        }
                                }
                            }
                        }
                    }
                    
                    // MARK: 5. Photo Documentation
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "PHOTO DOCUMENTATION")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(photos, id: \.self) { photoString in
                                    ZStack(alignment: .topTrailing) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(uiColor: .systemGray5))
                                            .frame(width: 70, height: 70)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundColor(.gray)
                                            )
                                        
                                        Button(action: {
                                            photos.removeAll { $0 == photoString }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Circle().fill(Color.white))
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                                
                                // Add Photo Button
                                Button(action: {
                                    // Add photo logic goes here
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.title3)
                                        Text("Add Photo")
                                            .font(.caption2)
                                    }
                                    .frame(width: 70, height: 70)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.vertical, 8)
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
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // MARK: 7. Internal Notes
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "INTERNAL NOTES")
                        
                        CardView {
                            TextField("Additional details only visible to mechanics...", text: $internalNotes, axis: .vertical)
                                .font(.subheadline)
                            // Added minHeight so the entire empty box is tappable
                                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                                .lineLimit(4...8)
                        }
                    }
                    
                    // MARK: 8. Create Button
                    Button(action: {
                        saveWorkOrderToSupabase()
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Work Order")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSaving ? Color.blue.opacity(0.7) : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                    .padding(.top, 10)
                    .padding(.bottom, 30) // Extra padding for scrolling
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // This makes sure the VStack takes up the whole width,
                // and any empty space inside the ScrollView routes to hideKeyboard.
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("New Work Order")
        .navigationBarTitleDisplayMode(.inline)
        // I have removed the '.toolbar' block here so there is no Done button anymore!
    }
    
    // MARK: - ViewModel Saving Logic
    private func saveWorkOrderToSupabase() {
        guard !isSaving else { return }
        isSaving = true
        
        Task {
            do {
                let newWorkOrderId = UUID()
                
                let newOrder = WorkOrder(
                    workOrderId: newWorkOrderId,
                    vehicleVin: vin.isEmpty ? "UNKNOWN-VIN" : vin,
                    vehicleName: vehicleName.isEmpty ? nil : vehicleName,
                    fleetUnitId: fleetId.isEmpty ? "UNKNOWN" : fleetId,
                    vehicleType: vehicleType,
                    priority: priority,
                    status: .pending,
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
                
                _ = parts.map { uiPart in
                    WorkOrderPart(
                        workOrderId: newWorkOrderId,
                        inventoryId: uiPart.inventoryId,
                        quantityRequired: uiPart.quantity,
                        costAtTime: nil
                    )
                }
                
                try await viewModel.upsertWorkOrder(newOrder)
                try await viewModel.insertTasks(workOrderTasks)
                
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
