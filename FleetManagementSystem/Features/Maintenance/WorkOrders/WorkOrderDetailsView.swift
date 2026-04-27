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
    @State private var editedLabourRate: String = "125.0"
    @State private var editedLabourCost: String = ""

    @State private var editablePhotos: [String] = []

    // MARK: - UI State
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false

    @State private var showingCompletionAlert: Bool = false
    @State private var showingCompletionReport: Bool = false
    @State private var saveTask: Task<Void, Never>?

    var isManagerApprovalMode: Bool = false

    // MARK: - Live Cost Calculations
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

    private var startButtonColor: Color {
        if !workOrder.isApproved {
            return .gray
        } else if isSaving {
            return Color.blue.opacity(0.7)
        } else {
            return .blue
        }
    }

    private var startButtonTitle: String {
        workOrder.isApproved ? "Start Work Order" : "Waiting for Approval"
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
                .hideKeyboardOnTap()

            ScrollView {
                if isLoading {
                    ProgressView("Loading details...")
                        .padding(.top, 50)
                } else {
                    mainContent
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Work Order")
        .navigationBarTitleDisplayMode(.inline)
        // Only loading our specific Toolbar items (the cross)
        .toolbar { toolbarContent }
        .alert("Complete Work Order?", isPresented: $showingCompletionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Generate Report") {
                completeWorkOrderAndShowReport()
            }
        } message: {
            Text("Are you sure you want to mark this task as completed and generate the final report?")
        }
        .sheet(isPresented: $showingCompletionReport) {
            WorkOrderCompletionReportView(workOrder: workOrder)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: editedIssueTitle) { _, _ in scheduleAutosave() }
        .onChange(of: editedIssueDescription) { _, _ in scheduleAutosave() }
        .onChange(of: editedHoursWorked) { _, _ in scheduleAutosave() }
        .onChange(of: editedLabourRate) { _, _ in scheduleAutosave() }
        .onChange(of: editedLabourCost) { _, _ in scheduleAutosave() }
        .onChange(of: editedMaintenanceNotes) { _, _ in scheduleAutosave() }
        .onDisappear {
            UIApplication.shared.endEditing()
            if !showingCompletionReport && !showingCompletionAlert {
                saveTask?.cancel()
                Task { await performSilentSave() }
            }
        }
        .task {
            await fetchWorkOrderDetails()
            await viewModel.fetchAllInventory()
        }
    }

    // MARK: - Extracted Main Content
    private var mainContent: some View {
        VStack(spacing: 24) {
            WorkOrderHeaderView(workOrder: workOrder)
            issueSummarySection
            tasksSection
            partsSection
            WorkEntryAndDocumentationView(
                viewModel: viewModel,
                editedHoursWorked: $editedHoursWorked,
                editedLabourRate: $editedLabourRate,
                editedLabourCost: $editedLabourCost,
                editedMaintenanceNotes: $editedMaintenanceNotes,
                photos: $editablePhotos
            )
            liveCostSection
            actionButtonSection
            Spacer().frame(height: 30)
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .hideKeyboardOnTap()
    }

    // MARK: - Extracted View Sections
    private var issueSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "ISSUE SUMMARY")
            EditableIssueSummaryCardView(
                issueTitle: $editedIssueTitle,
                issueDescription: $editedIssueDescription
            )
        }
    }

    private var tasksSection: some View {
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
                    addTaskRow
                }
            }
        }
    }

    private var addTaskRow: some View {
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

    private var partsSection: some View {
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
                    partsDropdownMenu
                }
            }
        }
    }

    private var partsDropdownMenu: some View {
        Menu {
            if viewModel.availableInventory.isEmpty {
                Text("Loading inventory...")
            } else {
                ForEach(viewModel.availableInventory) { item in
                    Button {
                        if !partsUI.contains(where: { $0.inventoryId == item.inventoryId }) {
                            partsUI.append(
                                PartDisplayInfo(
                                    inventoryId: item.inventoryId,
                                    name: item.partName,
                                    quantity: 1,
                                    unitCost: item.costPerUnit ?? 0.0
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

    private var liveCostSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "ESTIMATED COST SUMMARY")
            LiveCostTotalsView(
                labourTotal: labourTotalCost,
                partsTotal: partsTotalCost,
                tax: salesTax,
                total: finalTotalCost
            )
        }
    }

    @ViewBuilder
    private var actionButtonSection: some View {
        // 1. Manager Mode Buttons
        if isManagerApprovalMode && !workOrder.isApproved && workOrder.status != .cancelled {
            HStack(spacing: 16) {
                Button(action: { Task { await handleApproval(approved: false) } }) {
                    Text("Decline").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.red).cornerRadius(12)
                }
                Button(action: { Task { await handleApproval(approved: true) } }) {
                    Text("Approve").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.green).cornerRadius(12)
                }
            }
            .padding(.top, 10)
        }
        // 2. Mechanic View (Start Work Order)
        else if !isManagerApprovalMode && workOrder.status == .pending {
            Button {
                if workOrder.isApproved { startWorkOrder() }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView().progressViewStyle(.circular).tint(.white)
                    } else {
                        Text(startButtonTitle).font(.headline)
                    }
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding().background(startButtonColor).cornerRadius(12)
            }
            .disabled(!workOrder.isApproved || isSaving)
            .padding(.top, 10)
        }
        // 3. Mechanic View (Complete Work Order / View Report)
        else if (!isManagerApprovalMode && workOrder.status == .inProgress) || workOrder.status == .completed {
            Button {
                cancelPendingSave()
                if workOrder.status == .completed {
                    showingCompletionReport = true
                } else {
                    showingCompletionAlert = true
                }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView().progressViewStyle(.circular).tint(.white)
                    } else {
                        Text(workOrder.status == .completed ? "View Report" : "Complete Work Order").font(.headline)
                    }
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding()
                .background(Color(red: 163/255, green: 53/255, blue: 42/255)) // Brand red (#A3352A)
                .cornerRadius(12)
            }
            .disabled(isSaving)
            .padding(.top, 10)
        }
    }

    // 🚨 EXPLICITLY ONLY SHOWING THE CROSS BUTTON FOR EVERYONE
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .fontWeight(.semibold)
                    .foregroundColor(Color(red: 163/255, green: 53/255, blue: 42/255))
            }
        }
    }

    private func startWorkOrder() {
        cancelPendingSave()
        isSaving = true
        workOrder.status = .inProgress
        Task {
            await performSilentSave()
            await MainActor.run { isSaving = false }
        }
    }

    // MARK: - Manager Approval Logic
    private func handleApproval(approved: Bool) async {
        isSaving = true
        cancelPendingSave()

        do {
            let newStatus = approved ? WorkOrderStatus.pending.rawValue : WorkOrderStatus.cancelled.rawValue
            struct ApprovalUpdate: Encodable { let is_approved: Bool; let status: String }

            try await SupabaseManager.shared.client
                .from("work_orders")
                .update(ApprovalUpdate(is_approved: approved, status: newStatus))
                .eq("work_order_id", value: workOrder.workOrderId.uuidString)
                .execute()

            await sendResponseNotificationToMechanic(approved: approved)

            await MainActor.run {
                self.workOrder.isApproved = approved
                self.isSaving = false
                dismiss()
            }
        } catch {
            print("🚨 Failed to process approval: \(error)")
            await MainActor.run { self.isSaving = false }
        }
    }

    private func sendResponseNotificationToMechanic(approved: Bool) async {
        guard let mechanicId = workOrder.maintenancePersonnelId else { return }
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let managerId = session.user.id
            let statusString = approved ? "Approved" : "Declined"

            let responseNotification = NotificationInsertDTO(
                recipient_id: mechanicId,
                sender_id: managerId,
                title: "Work Order \(statusString)",
                message: "Your drafted Work Order '\(workOrder.issueTitle)' has been \(statusString.lowercased()).",
                type: NotificationType.maintenance.rawValue,
                related_entity_id: workOrder.workOrderId
            )

            try await SupabaseManager.shared.client.from("notifications").insert(responseNotification).execute()
        } catch {
            print("🚨 Failed to send response notification: \(error)")
        }
    }

    private func completeWorkOrderAndShowReport() {
        workOrder.status = .completed
        workOrder.updatedAt = Date()
        Task {
            await performSilentSave()
            await MainActor.run { showingCompletionReport = true }
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
            if !tasks.isEmpty { try await viewModel.upsertTasks(tasks) }

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

        let currentRate = Double(editedLabourRate) ?? 125.0
        editedLabourCost = String(format: "%.2f", initialHours * currentRate)
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
                            unitCost: inv.costPerUnit ?? 75.0
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
                    RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)).frame(width: 60, height: 60)
                    Image(systemName: workOrder.vehicle?.vehicleType?.sfSymbol ?? "car.fill").font(.title).foregroundColor(.blue)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(workOrder.vehicle?.vehicleName ?? workOrder.vehicle?.numberPlate ?? "Fleet Vehicle")
                        .font(.title3).fontWeight(.bold).foregroundColor(.primary)
                    Text("VIN: \(workOrder.vehicle?.vin ?? "VIN")").font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        Text("#WO-\(workOrder.workOrderId.uuidString.prefix(4).uppercased())")
                            .font(.caption2).fontWeight(.bold).foregroundColor(.blue).padding(.horizontal, 8).padding(.vertical, 4).background(Color.blue.opacity(0.1)).clipShape(Capsule())
                        Text(workOrder.priority.rawValue.uppercased())
                            .font(.caption2).fontWeight(.bold).padding(.horizontal, 8).padding(.vertical, 4).background(priorityBackgroundColor).foregroundColor(priorityTextColor).clipShape(Capsule())
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
                TextField("Issue Title", text: $issueTitle).font(.headline).fontWeight(.bold).foregroundColor(Color(red: 0.65, green: 0.35, blue: 0.15)).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                TextField("Detailed description...", text: $issueDescription, axis: .vertical).font(.subheadline).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading).lineLimit(3...6)
            }
        }
    }
}

struct WorkEntryAndDocumentationView: View {
    @ObservedObject var viewModel: WorkOrderViewModel
    @Binding var editedHoursWorked: String
    @Binding var editedLabourRate: String
    @Binding var editedLabourCost: String
    @Binding var editedMaintenanceNotes: String
    @Binding var photos: [String]

    @State private var showImagePicker = false
    @State private var showSourceTypePicker = false
    @State private var imageSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var photoToReplace: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            workEntrySection
            maintenanceNotesSection
            photoDocumentationSection
        }
        .confirmationDialog("Select Image Source", isPresented: $showSourceTypePicker, titleVisibility: .visible) {
            Button("Camera") { imageSource = .camera; showImagePicker = true }
            Button("Photo Library") { imageSource = .photoLibrary; showImagePicker = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imageSource) { image in
                if let imageData = image.jpegData(compressionQuality: 0.7) {
                    let filename = UUID().uuidString + ".jpg"
                    Task {
                        do {
                            let uploadedImageUrl = try await viewModel.uploadImageToSupabase(imageData: imageData, fileName: filename)
                            await MainActor.run {
                                if let target = photoToReplace, let index = photos.firstIndex(of: target) {
                                    photos[index] = uploadedImageUrl
                                } else {
                                    photos.append(uploadedImageUrl)
                                }
                                photoToReplace = nil
                            }
                        } catch { print("🚨 Failed to upload image: \(error)") }
                    }
                }
            }
        }
    }

    private var workEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "WORK ENTRY")
            CardView {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HOURS").font(.caption2).fontWeight(.medium).foregroundColor(.secondary)
                        TextField("0.0", text: $editedHoursWorked).font(.subheadline).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).onChange(of: editedHoursWorked) { _, _ in recalculateLabourCost() }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RATE/HR (₹)").font(.caption2).fontWeight(.medium).foregroundColor(.secondary)
                        TextField("0.0", text: $editedLabourRate).font(.subheadline).keyboardType(.decimalPad).textFieldStyle(.roundedBorder).onChange(of: editedLabourRate) { _, _ in recalculateLabourCost() }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOTAL (₹)").font(.caption2).fontWeight(.medium).foregroundColor(.secondary)
                        TextField("0.00", text: $editedLabourCost).font(.subheadline).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
    }

    private func recalculateLabourCost() {
        let hours = Double(editedHoursWorked) ?? 0.0
        let rate = Double(editedLabourRate) ?? 0.0
        editedLabourCost = String(format: "%.2f", hours * rate)
    }

    private var maintenanceNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "MAINTENANCE NOTES")
            CardView {
                TextEditor(text: $editedMaintenanceNotes)
                    .font(.subheadline).frame(minHeight: 100).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(uiColor: .systemGray5), lineWidth: 1))
            }
        }
    }

    private var photoDocumentationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: "DOCUMENTATION")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    Button(action: { photoToReplace = nil; showSourceTypePicker = true }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .systemGray5)).frame(width: 110, height: 110)
                            Image(systemName: "plus").font(.system(size: 32, weight: .semibold)).foregroundColor(.blue)
                        }
                    }.padding(.leading, 1)

                    ForEach(photos, id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty: ZStack { RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .systemGray6)).frame(width: 110, height: 110); ProgressView() }
                                case .success(let image): image.resizable().scaledToFill().frame(width: 110, height: 110).clipShape(RoundedRectangle(cornerRadius: 16))
                                case .failure: ZStack { RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .systemGray6)).frame(width: 110, height: 110); Image(systemName: "exclamationmark.triangle").foregroundColor(.red) }
                                @unknown default: EmptyView()
                                }
                            }
                            .contextMenu {
                                Button(action: { photoToReplace = urlString; showSourceTypePicker = true }) { Label("Replace", systemImage: "arrow.triangle.2.circlepath") }
                                Button(role: .destructive, action: { withAnimation { photos.removeAll { $0 == urlString } } }) { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }.padding(.top, 10).padding(.horizontal, 16)
            }
        }
    }
}

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
                Text("Estimated Total Cost").font(.headline).fontWeight(.bold).foregroundColor(.primary)
                Spacer()
                Text(String(format: "₹%.2f", total)).font(.title3).fontWeight(.bold).foregroundColor(.green)
            }
        }.padding().background(Color.green.opacity(0.1)).cornerRadius(12)
    }
}

struct LiveCostRow: View {
    let label: String
    let value: Double
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(String(format: "₹%.2f", value)).font(.headline).foregroundColor(.primary)
        }
    }
}

struct SectionHeaderView: View {
    let title: String
    var body: some View {
        Text(title).font(.caption).fontWeight(.bold).foregroundColor(.secondary).tracking(1.0).padding(.leading, 4)
    }
}

struct CardView<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding().background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(12)
    }
}

struct PartDetailRowView: View {
    @Binding var part: PartDisplayInfo
    var onQuantityChange: () -> Void
    var onDelete: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(part.name).font(.subheadline).fontWeight(.medium)
                Text(String(format: "₹%.2f ea", part.unitCost)).font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 16) {
                Button(action: { if part.quantity > 1 { part.quantity -= 1; onQuantityChange() } }) { Image(systemName: "minus").foregroundColor(.blue) }
                Text("\(part.quantity)").font(.subheadline).fontWeight(.medium)
                Button(action: { part.quantity += 1; onQuantityChange() }) { Image(systemName: "plus").foregroundColor(.blue) }
            }.padding(.horizontal, 12).padding(.vertical, 8).background(Color(uiColor: .systemGray6)).cornerRadius(8)
            Button(action: onDelete) { Image(systemName: "trash.fill").foregroundColor(.red.opacity(0.8)) }.padding(.leading, 8)
        }
    }
}

#Preview {
    NavigationStack {
        WorkOrderDetailView(
            workOrder: WorkOrder(
                workOrderId: UUID(),
                vehicleId: UUID(),
                maintenancePersonnelId: UUID(),
                vehicle: WorkOrderVehicle(
                    vehicleId: UUID(),
                    vin: "FL-9902-XJ",
                    numberPlate: "UNIT-01",
                    vehicleName: "Freightliner Cascadia",
                    vehicleType: .car
                ),
                priority: .high,
                status: .pending,
                isApproved: false,
                issueTitle: "Engine System Fault",
                issueDescription: "Operator reports intermittent power loss and check engine light.",
                hoursWorked: 2.5,
                estCost: 450.0,
                internalNotes: nil,
                maintenanceNotes: "Replaced air filtration system.",
                images: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            isManagerApprovalMode: true
        )
    }
}
