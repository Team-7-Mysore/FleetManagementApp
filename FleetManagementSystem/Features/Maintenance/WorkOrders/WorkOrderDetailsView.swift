import SwiftUI
import Supabase

// MARK: - Update PartDisplayInfo
struct PartDisplayInfo: Identifiable, Equatable {
    let id = UUID()
    var inventoryId: UUID
    var name: String
    var quantity: Int
    var sfIconName: String = "gearshape.fill"
    var unitCost: Double = 0.0
}

struct WorkOrderDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = WorkOrderViewModel()
    @State var workOrder: WorkOrder

    // MARK: - Fetched Relational Data
    @State private var tasks: [WorkOrderTask] = []
    @State private var partsUI: [PartDisplayInfo] = []

    // MARK: - Editable Fields
    @State private var editedIssueTitle: String = ""
    @State private var editedIssueDescription: String = ""

    @State private var newTaskName: String = ""

    @State private var editedMaintenanceNotes: String = ""
    @State private var editedHoursWorked: String = ""
    @State private var editedLabourCost: String = ""

    @State private var editablePhotos: [String] = []

    // MARK: - UI State
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false

    @State private var showingCompletionAlert: Bool = false
    @State private var showingCompletionReport: Bool = false
    @State private var saveTask: Task<Void, Never>?

    // MARK: - Live Cost Calculations
    private let defaultLabourRate = 125.0

    private var parsedHours: Double {
        Double(editedHoursWorked) ?? 0.0
    }

    private var labourTotalCost: Double {
        Double(editedLabourCost) ?? 0.0
    }

    private var partsTotalCost: Double {
        partsUI.reduce(0) { total, part in
            total + (Double(part.quantity) * part.unitCost)
        }
    }

    private var subtotal: Double {
        labourTotalCost + partsTotalCost
    }

    private var salesTax: Double {
        subtotal * 0.13
    }

    private var finalTotalCost: Double {
        subtotal + salesTax
    }

    var body: some View {
        // ZStack to prevent the keyboard from pushing the background up
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
                .onTapGesture { hideKeyboard() }

            ScrollView {
                if isLoading {
                    ProgressView("Loading details...")
                        .padding(.top, 50)
                } else {
                    VStack(spacing: 24) {

                        // MARK: 1. Header Section
                        WorkOrderHeaderView(workOrder: workOrder)

                        // MARK: 2. Issue Summary (Editable)
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "ISSUE SUMMARY")
                            EditableIssueSummaryCardView(
                                issueTitle: $editedIssueTitle,
                                issueDescription: $editedIssueDescription
                            )
                        }

                        // MARK: 3. Task Checklist
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "MAINTENANCE TASKS")
                            CardView {
                                VStack(alignment: .leading, spacing: 12) {
                                    if tasks.isEmpty {
                                        Text("No tasks assigned.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        ForEach($tasks) { $task in
                                            HStack(spacing: 12) {
                                                Button(action: {
                                                    task.isCompleted.toggle()
                                                    scheduleAutosave()
                                                }) {
                                                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                                        .foregroundColor(task.isCompleted ? .blue : Color(uiColor: .systemGray4))
                                                        .font(.title3)
                                                }

                                                Text(task.description)
                                                    .font(.subheadline)
                                                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                                                    .strikethrough(task.isCompleted)

                                                Spacer()
                                            }
                                            .padding(.vertical, 4)
                                            Divider()
                                        }
                                    }

                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)

                                        TextField("Add Task...", text: $newTaskName)
                                            .font(.subheadline)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .onSubmit {
                                                guard !newTaskName.isEmpty else { return }
                                                tasks.append(WorkOrderTask(
                                                    taskId: UUID(),
                                                    workOrderId: workOrder.workOrderId,
                                                    description: newTaskName,
                                                    isCompleted: false,
                                                    createdAt: Date()
                                                ))
                                                newTaskName = ""
                                                scheduleAutosave()
                                            }
                                    }
                                }
                            }
                        }

                        // MARK: 4. Parts Required Section
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "PARTS REQUIRED")
                            CardView {
                                VStack(alignment: .leading, spacing: 8) {
                                    if partsUI.isEmpty {
                                        Text("No parts requested.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.bottom, 8)
                                    } else {
                                        ForEach($partsUI) { $part in
                                            PartDetailRowView(part: $part, onQuantityChange: {
                                                scheduleAutosave()
                                            }, onDelete: {
                                                partsUI.removeAll { $0.id == part.id }
                                                scheduleAutosave()
                                            })
                                            .padding(.vertical, 4)
                                            Divider()
                                        }
                                    }

                                    // FIX: Parts Dropdown Menu
                                    Menu {
                                        if viewModel.availableInventory.isEmpty {
                                            Text("Loading inventory...")
                                        } else {
                                            ForEach(viewModel.availableInventory) { item in
                                                Button {
                                                    // Prevent adding duplicate parts
                                                    if !partsUI.contains(where: { $0.inventoryId == item.inventoryId }) {
                                                        partsUI.append(
                                                            PartDisplayInfo(
                                                                inventoryId: item.inventoryId,
                                                                name: item.partName,
                                                                quantity: 1,
                                                                unitCost: item.costPerUnit ?? 0.0 // Grab real unit cost
                                                            )
                                                        )
                                                        scheduleAutosave()
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

                        // MARK: 5. Work Entry & Documentation Section
                        WorkEntryAndDocumentationView(
                            editedHoursWorked: $editedHoursWorked,
                            editedLabourCost: $editedLabourCost,
                            defaultLabourRate: defaultLabourRate,
                            editedMaintenanceNotes: $editedMaintenanceNotes,
                            photos: $editablePhotos
                        )

                        // MARK: 6. LIVE COST SUMMARY
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "ESTIMATED COST SUMMARY")
                            LiveCostTotalsView(
                                labourTotal: labourTotalCost,
                                partsTotal: partsTotalCost,
                                tax: salesTax,
                                total: finalTotalCost
                            )
                        }

                        // MARK: 7. Action Buttons
                        if workOrder.status == .pending {
                            Button(action: {
                                startWorkOrder()
                            }) {
                                HStack {
                                    if isSaving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Start Work Order")
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isSaving ? Color.blue.opacity(0.7) : Color.blue)
                                .cornerRadius(12)
                            }
                            .padding(.top, 10)
                        }

                        Spacer().frame(height: 30) // Bottom padding
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom) // Prevents pushing background up
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Work Order")
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Toolbar Items
        .toolbar {
            // Close button for modal presentation
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    dismiss()
                }
            }

            // Generate / View Report Button
            if workOrder.status == .inProgress || workOrder.status == .completed {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        cancelPendingSave()
                        if workOrder.status == .completed {
                            showingCompletionReport = true // Skip alert if already completed
                        } else {
                            showingCompletionAlert = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(workOrder.status == .completed ? "View Report" : "Done")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(Color(hex: "#A3352A"))
                    }
                }
            }
        }

        // MARK: - Navigation Triggers
        .alert("Complete Work Order?", isPresented: $showingCompletionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Generate Report", role: .none) {
                completeWorkOrderAndShowReport()
            }
        } message: {
            Text("Are you sure you want to mark this task as completed and generate the final report?")
        }
        .sheet(isPresented: $showingCompletionReport) {
            WorkOrderCompletionReportView(
                workOrder: workOrder
            )
            .presentationDragIndicator(.visible)
        }

        // MARK: - Autosave Triggers
        .onChange(of: editedIssueTitle) {
            scheduleAutosave()
        }
        .onChange(of: editedIssueDescription) {
            scheduleAutosave()
        }
        .onChange(of: editedHoursWorked) {
            scheduleAutosave()
        }
        .onChange(of: editedLabourCost) {
            scheduleAutosave()
        }
        .onChange(of: editedMaintenanceNotes) {
            scheduleAutosave()
        }

        .onDisappear {
            hideKeyboard() // Clear keyboard on modal dismiss
            if !showingCompletionReport && !showingCompletionAlert {
                saveTask?.cancel()
                Task {
                    await performSilentSave()
                }
            }
        }
        .task {
            // Fetch everything when view loads
            await fetchWorkOrderDetails()
            await viewModel.fetchAllInventory()
        }
    }

    // MARK: - Actions
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func startWorkOrder() {
        cancelPendingSave()
        isSaving = true
        workOrder.status = .inProgress
        Task {
            await performSilentSave()
            await MainActor.run {
                isSaving = false
            }
        }
    }

    private func completeWorkOrderAndShowReport() {
        workOrder.status = .completed
        workOrder.updatedAt = Date()

        Task {
            await performSilentSave()
            await MainActor.run {
                showingCompletionReport = true
            }
        }
    }

    // MARK: - Autosave Logic
    private func scheduleAutosave() {
        guard !isLoading else { return }
        cancelPendingSave()

        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            await performSilentSave()
        }
    }

    private func cancelPendingSave() {
        saveTask?.cancel()
    }

    private func performSilentSave() async {
        workOrder.issueTitle = editedIssueTitle
        workOrder.issueDescription = editedIssueDescription.isEmpty ? nil : editedIssueDescription
        workOrder.hoursWorked = Double(editedHoursWorked) ?? workOrder.hoursWorked
        workOrder.estCost = finalTotalCost
        workOrder.maintenanceNotes = editedMaintenanceNotes.isEmpty ? nil : editedMaintenanceNotes
        workOrder.images = editablePhotos.isEmpty ? nil : editablePhotos
        workOrder.updatedAt = Date()

        do {
            try await viewModel.upsertWorkOrder(workOrder)

            if !tasks.isEmpty {
                try await viewModel.upsertTasks(tasks)
            }

            // Re-map the parts to update DB
            let workOrderParts = partsUI.map { uiPart in
                WorkOrderPart(
                    workOrderId: workOrder.workOrderId,
                    inventoryId: uiPart.inventoryId,
                    quantityRequired: uiPart.quantity,
                    costAtTime: uiPart.unitCost
                )
            }
            try await viewModel.upsertParts(workOrderParts)

        } catch {
            print("🚨 Autosave failed: \(error)")
        }
    }

    // MARK: - Fetch Relational Data
    private func fetchWorkOrderDetails() async {
        editedIssueTitle = workOrder.issueTitle
        editedIssueDescription = workOrder.issueDescription ?? ""
        editedMaintenanceNotes = workOrder.maintenanceNotes ?? ""

        let initialHours = workOrder.hoursWorked ?? 0.0
        editedHoursWorked = String(format: "%.1f", initialHours)

        // Calculate initial labour cost based on hours
        editedLabourCost = String(format: "%.2f", initialHours * defaultLabourRate)

        editablePhotos = workOrder.images ?? []

        do {
            let fetchedTasks = try await viewModel.fetchTasks(for: workOrder.workOrderId)
            let fetchedParts = try await viewModel.fetchParts(for: workOrder.workOrderId)

            var mappedParts: [PartDisplayInfo] = []
            if !fetchedParts.isEmpty {
                let inventoryIds = fetchedParts.map { $0.inventoryId }
                let fetchedInventory = try await viewModel.fetchInventory(for: inventoryIds)

                for wp in fetchedParts {
                    if let inv = fetchedInventory.first(where: { $0.inventoryId == wp.inventoryId }) {
                        mappedParts.append(PartDisplayInfo(
                            inventoryId: inv.inventoryId,
                            name: inv.partName,
                            quantity: wp.quantityRequired,
                            unitCost: inv.costPerUnit ?? 75.0 // Fallback cost if DB is empty
                        ))
                    }
                }
            }

            await MainActor.run {
                self.tasks = fetchedTasks
                self.partsUI = mappedParts
                self.isLoading = false
            }
        } catch {
            print("🚨 Failed to fetch details: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
}

// MARK: - Reusable UI Subviews

struct WorkOrderHeaderView: View {
    let workOrder: WorkOrder

    var body: some View {
        CardView {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: workOrder.vehicleType.sfSymbol)
                        .font(.title)
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(workOrder.vehicleName ?? "Fleet Vehicle")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("VIN: \(workOrder.vehicleVin)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Text("#WO-\(workOrder.workOrderId.uuidString.prefix(4).uppercased())")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())

                        Text(workOrder.priority.rawValue.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(priorityBackgroundColor)
                            .foregroundColor(priorityTextColor)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
        }
    }

    private var priorityBackgroundColor: Color {
        switch workOrder.priority {
        case .low: return Color.green.opacity(0.1)
        case .medium: return Color.orange.opacity(0.1)
        case .high, .urgent: return Color.red.opacity(0.1)
        }
    }

    private var priorityTextColor: Color {
        switch workOrder.priority {
        case .low: return .green
        case .medium: return .orange
        case .high, .urgent: return .red
        }
    }
}

struct EditableIssueSummaryCardView: View {
    @Binding var issueTitle: String
    @Binding var issueDescription: String

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 0) {
                TextField("Issue Title", text: $issueTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.65, green: 0.35, blue: 0.15))
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                TextField("Detailed description...", text: $issueDescription, axis: .vertical)
                    .font(.subheadline)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                    .lineLimit(3...6)
            }
        }
    }
}

struct WorkEntryAndDocumentationView: View {
    @Binding var editedHoursWorked: String
    @Binding var editedLabourCost: String
    let defaultLabourRate: Double
    @Binding var editedMaintenanceNotes: String
    @Binding var photos: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            VStack(alignment: .leading, spacing: 8) {
                SectionHeaderView(title: "WORK ENTRY")
                CardView {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HOURS WORKED")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            TextField("0.0", text: $editedHoursWorked)
                                .font(.subheadline)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: editedHoursWorked) { _, newValue in
                                    if let hours = Double(newValue) {
                                        editedLabourCost = String(format: "%.2f", hours * defaultLabourRate)
                                    } else {
                                        editedLabourCost = "0.00"
                                    }
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("LABOUR COST (₹)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)

                            TextField("0.00", text: $editedLabourCost)
                                .font(.subheadline)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeaderView(title: "MAINTENANCE NOTES")
                CardView {
                    TextEditor(text: $editedMaintenanceNotes)
                        .font(.subheadline)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(uiColor: .systemGray5), lineWidth: 1)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeaderView(title: "DOCUMENTATION")
                CardView {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(photos, id: \.self) { urlString in
                                AsyncImage(url: URL(string: urlString)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Color.gray.opacity(0.3).overlay(Image(systemName: "photo"))
                                    }
                                }
                                .frame(width: 70, height: 70)
                                .cornerRadius(12)
                                .clipped()
                            }

                            Button(action: { }) {
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
                    }
                }
            }
        }
    }
}

// MARK: - Live Cost Block
struct LiveCostTotalsView: View {
    let labourTotal: Double
    let partsTotal: Double
    let tax: Double
    let total: Double

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                LiveCostRow(label: "Labour Cost", value: labourTotal)
                LiveCostRow(label: "Parts subtotal", value: partsTotal)
                LiveCostRow(label: "GST/Tax (13%)", value: tax)
            }

            Divider().padding(.vertical, 4)

            HStack {
                Text("Estimated Total Cost")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "₹%.2f", total))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

struct LiveCostRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "₹%.2f", value))
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Core Components
struct SectionHeaderView: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.secondary)
            .tracking(1.0)
            .padding(.leading, 4)
    }
}

struct CardView<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
    }
}

// MARK: - NEW FIX: Extracted Part Row Subview
struct PartDetailRowView: View {
    @Binding var part: PartDisplayInfo
    var onQuantityChange: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(part.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(String(format: "₹%.2f ea", part.unitCost))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: {
                    if part.quantity > 1 {
                        part.quantity -= 1
                        onQuantityChange()
                    }
                }) {
                    Image(systemName: "minus")
                        .foregroundColor(.blue)
                }

                Text("\(part.quantity)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Button(action: {
                    part.quantity += 1
                    onQuantityChange()
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(8)

            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red.opacity(0.8))
            }
            .padding(.leading, 8)
        }
    }
}

#Preview {
    NavigationStack {
        WorkOrderDetailView(workOrder: WorkOrder(
            workOrderId: UUID(),
            vehicleVin: "FL-9902-XJ",
            vehicleName: "Freightliner Cascadia",
            fleetUnitId: "UNIT-01",
            vehicleType: .truck,
            priority: .high,
            status: .inProgress,
            isApproved: false,
            issueTitle: "Engine System Fault",
            issueDescription: "Operator reports intermittent power loss and check engine light.",
            hoursWorked: 2.5,
            estCost: 450.0,
            maintenanceNotes: "Replaced air filtration system.",
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
}
