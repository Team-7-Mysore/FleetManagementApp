import SwiftUI

struct WorkOrderCompletionReportView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel = WorkOrderViewModel()
    
    // Data passed from the details view
    @Binding var workOrder: WorkOrder
    @Binding var tasks: [WorkOrderTask]
    @Binding var partsUI: [PartDisplayInfo]
    @Binding var maintenanceNotes: String
    
    // Custom labour cost passed from the edits in the Details View
    var labourCost: Double
    
    @State private var isSaving: Bool = false
    
    private var totalHours: Double {
        Double(workOrder.hoursWorked ?? 0.0)
    }
    
    private var partsTotalCost: Double {
        partsUI.reduce(0) { total, part in
            total + (Double(part.quantity) * part.unitCost)
        }
    }
    
    private var subtotal: Double {
        labourCost + partsTotalCost
    }
    
    private var salesTax: Double {
        subtotal * 0.13
    }
    
    private var finalTotalCost: Double {
        subtotal + salesTax
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - A. SECTION 1: KEEPING EXISTING DETAILS HIERARCHY
                    VStack(spacing: 24) {
                        ReportpreservedHeaderView(workOrder: workOrder)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ReportSectionHeaderView(title: "ISSUE SUMMARY")
                            ReportCardView {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color(red: 0.65, green: 0.35, blue: 0.15))
                                        .font(.headline)
                                        .padding(.top, 2)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(workOrder.issueTitle)
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(red: 0.65, green: 0.35, blue: 0.15))
                                        
                                        if let desc = workOrder.issueDescription {
                                            Text(desc)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                        
                        // Tasks List
                        VStack(alignment: .leading, spacing: 8) {
                            ReportSectionHeaderView(title: "MAINTENANCE TASKS CHECKLIST")
                            ReportCardView {
                                VStack(alignment: .leading, spacing: 12) {
                                    if tasks.isEmpty {
                                        Text("No tasks provided.")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        ForEach(tasks) { task in
                                            HStack(spacing: 12) {
                                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(task.isCompleted ? .green : .secondary)
                                                    .font(.title3)
                                                
                                                Text(task.description)
                                                    .font(.subheadline)
                                                    .foregroundColor(task.isCompleted ? .primary : .secondary)
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 4)
                                            if task.id != tasks.last?.id { Divider() }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // MARK: - B. SECTION 2: FINAL SUMMARY FORMAT (Matches Screenshot)
                    VStack(alignment: .leading, spacing: 20) {
                        
                        Text("FINAL SERVICE SUMMARY")
                            .font(.headline)
                            .tracking(1.0)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 10)
                        
                        SummaryPartsUsedBlockView(parts: partsUI)
                        
                        Divider()
                        
                        SummaryNotesBlockView(notes: maintenanceNotes)
                        
                        Divider()
                        
                        // FIX: Static Side-By-Side Time & Labour Boxes
                        StaticTimeAndLabourBlockView(totalHours: totalHours, totalLabour: labourCost)
                        
                        ReportCostTotalsView(subtotal: subtotal, labourCost: labourCost, tax: salesTax, total: finalTotalCost)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer().frame(height: 30)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Complete Work Order")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        finalizeWorkOrderInSupabase()
                    }) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Generate")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
    
    // MARK: - Save Logic
    private func finalizeWorkOrderInSupabase() {
        guard !isSaving else { return }
        isSaving = true
        
        workOrder.status = .completed
        workOrder.updatedAt = Date() // Updates to the exact moment it's finalized
        workOrder.maintenanceNotes = maintenanceNotes.isEmpty ? nil : maintenanceNotes
        
        Task {
            do {
                try await viewModel.upsertWorkOrder(workOrder)
                try await viewModel.upsertTasks(tasks)
                
                if !partsUI.isEmpty {
                    let partsToSave = partsUI.map { uiPart in
                        WorkOrderPart(
                            workOrderId: workOrder.workOrderId,
                            inventoryId: uiPart.inventoryId,
                            quantityRequired: uiPart.quantity,
                            costAtTime: uiPart.unitCost
                        )
                    }
                    try await viewModel.upsertParts(partsToSave)
                }
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                print("🚨 Finalization failed: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - Subviews
struct ReportpreservedHeaderView: View {
    let workOrder: WorkOrder
    
    var body: some View {
        ReportCardView {
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
                        
                        Text("COMPLETING")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
        }
    }
}

struct ReportSectionHeaderView: View {
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

struct ReportCardView<Content: View>: View {
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

struct SummaryPartsUsedBlockView: View {
    let parts: [PartDisplayInfo]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("PARTS USED", systemImage: "puzzlepiece.fill")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.0)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                if parts.isEmpty {
                    Text("No parts used.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    ForEach(parts) { part in
                        HStack(spacing: 12) {
                            Text("\(part.quantity)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            Text(part.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(String(format: "$%.2f", part.unitCost))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(uiColor: .systemGray5), lineWidth: 1))
                    }
                }
            }
        }
    }
}

// FIX: New Static Box matching your screenshot
struct StaticTimeAndLabourBlockView: View {
    let totalHours: Double
    let totalLabour: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("TIME & LABOUR", systemImage: "timer")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.0)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOURS WORKED")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.1f", totalHours))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(uiColor: .systemGray5), lineWidth: 1))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("LABOUR COST ($)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.2f", totalLabour))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(uiColor: .systemGray5), lineWidth: 1))
                }
            }
        }
    }
}

struct SummaryNotesBlockView: View {
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("MAINTENANCE NOTES", systemImage: "doc.plaintext.fill")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.0)
                .foregroundColor(.secondary)
            
            Text(notes.isEmpty ? "No internal notes provided." : notes)
                .font(.subheadline)
                .foregroundColor(notes.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(uiColor: .systemGray5), lineWidth: 1))
        }
    }
}

struct ReportCostTotalsView: View {
    let subtotal: Double
    let labourCost: Double
    let tax: Double
    let total: Double
    
    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 8) {
                ReportCostRow(label: "Labour Cost", value: labourCost)
                ReportCostRow(label: "Parts subtotal", value: subtotal - labourCost)
                ReportCostRow(label: "GST/Tax (13%)", value: tax)
            }
            
            Divider().padding(.vertical, 4)
            
            HStack {
                Text("Total Service Cost")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "$%.2f", total))
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

struct ReportCostRow: View {
    let label: String
    let value: Double
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "$%.2f", value))
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    WorkOrderCompletionReportView(
        workOrder: .constant(WorkOrder(
            workOrderId: UUID(),
            vehicleVin: "FL-9902-XJ",
            vehicleName: "Freightliner Cascadia",
            fleetUnitId: "UNIT-01",
            vehicleType: .truck,
            priority: .high,
            status: .inProgress,
            issueTitle: "Engine System Fault",
            issueDescription: "Operator reports intermittent power loss and check engine light.",
            hoursWorked: 3.5,
            estCost: 450.0,
            maintenanceNotes: "Replaced primary air filtration system. Flushed engine lines. System passed diagnostic test.",
            createdAt: Date(),
            updatedAt: Date()
        )),
        tasks: .constant([
            WorkOrderTask(taskId: UUID(), workOrderId: UUID(), description: "Diagnose intermittent power loss", isCompleted: true, createdAt: Date()),
            WorkOrderTask(taskId: UUID(), workOrderId: UUID(), description: "Replace air filtration system", isCompleted: true, createdAt: Date()),
            WorkOrderTask(taskId: UUID(), workOrderId: UUID(), description: "Perform system reset", isCompleted: false, createdAt: Date())
        ]),
        partsUI: .constant([
            PartDisplayInfo(inventoryId: UUID(), name: "Air Filter - FX4", quantity: 1, unitCost: 112.50),
            PartDisplayInfo(inventoryId: UUID(), name: "Engine Seal Gasket", quantity: 2, unitCost: 35.00)
        ]),
        maintenanceNotes: .constant("Replaced primary air filtration system. Flushed engine lines. System passed diagnostic test."),
        labourCost: 437.50
    )
}
