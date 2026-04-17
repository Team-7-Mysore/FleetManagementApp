import SwiftUI

struct WorkOrderCompletionReportView: View {
    @Environment(\.dismiss) private var dismiss
    let workOrder: WorkOrder
    
    // ViewModel to fetch the tasks and parts
    @StateObject private var viewModel = WorkOrderViewModel()
    
    @State private var tasks: [WorkOrderTask] = []
    @State private var partsUI: [PartDisplayInfo] = []
    @State private var isLoading: Bool = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Generating Report...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // MARK: - 1. Vehicle & Work Order Header
                            ReportHeaderCard(workOrder: workOrder)
                            
                            // MARK: - 2. Issue Summary
                            ReportSectionView(title: "ISSUE SUMMARY") {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(workOrder.issueTitle)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if let description = workOrder.issueDescription {
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineSpacing(4)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(uiColor: .systemGray6))
                                .cornerRadius(12)
                            }
                            
                            // MARK: - 3. Completed Tasks
                            if !tasks.isEmpty {
                                ReportSectionView(title: "COMPLETED TASKS") {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(tasks.enumerated()), id: \.element.taskId) { index, task in
                                            HStack(spacing: 16) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                                    .font(.title3)
                                                
                                                Text(task.description)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 16)
                                            .padding(.horizontal, 16)
                                            
                                            if index < tasks.count - 1 {
                                                Divider().padding(.leading, 48)
                                            }
                                        }
                                    }
                                    .background(Color(uiColor: .systemBackground))
                                    .cornerRadius(12)
                                }
                            }
                            
                            // MARK: - 4. Parts & Materials
                            if !partsUI.isEmpty {
                                ReportSectionView(title: "PARTS & MATERIALS") {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(partsUI.enumerated()), id: \.element.id) { index, part in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(part.name)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.primary)
                                                    
                                                    // Using the prefix of the ID as the Part Number to match design
                                                    Text("PN: \(part.inventoryId.uuidString.prefix(8).uppercased())")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Text("x\(part.quantity)")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(Color(uiColor: .systemGray6))
                                                    .clipShape(Capsule())
                                            }
                                            .padding(.vertical, 14)
                                            .padding(.horizontal, 16)
                                            
                                            if index < partsUI.count - 1 {
                                                Divider().padding(.leading, 16)
                                            }
                                        }
                                    }
                                    .background(Color(uiColor: .systemBackground))
                                    .cornerRadius(12)
                                }
                            } else {
                                // Fallback view just in case parts aren't successfully saving to DB yet
                                // This ensures the section header doesn't disappear silently while you debug DB fetching
                                ReportSectionView(title: "PARTS & MATERIALS") {
                                    Text("No parts recorded for this work order.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(uiColor: .systemBackground))
                                        .cornerRadius(12)
                                }
                            }
                            
                            // MARK: - 5. Service Metrics & Notes
                            ReportSectionView(title: "SERVICE METRICS") {
                                VStack(spacing: 0) {
                                    ReportRowView(label: "Hours Worked", value: String(format: "%.1f hrs", workOrder.hoursWorked ?? 0.0))
                                        .padding()
                                    Divider().padding(.leading, 16)
                                    ReportRowView(label: "Estimated Cost", value: String(format: "$%.2f", workOrder.estCost ?? 0.0))
                                        .padding()
                                }
                                .background(Color(uiColor: .systemBackground))
                                .cornerRadius(12)
                            }
                            
                            if let notes = workOrder.maintenanceNotes {
                                ReportSectionView(title: "MECHANIC NOTES") {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding()
                                        .background(Color(uiColor: .systemBackground))
                                        .cornerRadius(12)
                                }
                            }
                            
                            // Footer timestamp
                            if let completedDate = workOrder.updatedAt {
                                Text("Report generated on \(completedDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(.top, 10)
                                    .padding(.bottom, 30)
                            }
                        }
                        .padding()
                    }
                }
            }
            // MARK: - Native iOS Navigation Modifiers
            .navigationTitle("Work Order Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                    }
                }
            }
            .task {
                await fetchReportData()
            }
        }
    }
    
    // MARK: - Data Fetching
    private func fetchReportData() async {
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
                            unitCost: inv.costPerUnit ?? 0.0
                        ))
                    }
                }
            }
            
            await MainActor.run {
                self.tasks = fetchedTasks.filter { $0.isCompleted }
                self.partsUI = mappedParts
                self.isLoading = false
            }
        } catch {
            print("🚨 Failed to load report data: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
}

// MARK: - Subviews

struct ReportHeaderCard: View {
    let workOrder: WorkOrder
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Top Row: Title & Status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VEHICLE ASSET")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Text(workOrder.vehicleName ?? "Fleet Vehicle")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("ID: \(workOrder.fleetUnitId ?? "N/A")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(workOrder.status.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(workOrder.status == .completed ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundColor(workOrder.status == .completed ? Color(red: 0.1, green: 0.5, blue: 0.2) : .orange)
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Bottom Grid (Updated to remove Priority, move Date, and span VIN)
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    ReportDetailColumn(
                        title: "WORK ORDER ID",
                        value: "WO-\(workOrder.workOrderId.uuidString.prefix(6).uppercased())"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ReportDetailColumn(
                        title: "SERVICE DATE",
                        value: workOrder.updatedAt?.formatted(date: .abbreviated, time: .omitted) ?? "N/A"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // VIN gets its own full-width row now
                ReportDetailColumn(
                    title: "VIN",
                    value: workOrder.vehicleVin
                )
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.02), radius: 8, x: 0, y: 4)
    }
}

struct ReportDetailColumn: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(valueColor)
        }
    }
}

struct ReportSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .tracking(0.8)
                .padding(.leading, 4)
            
            content
        }
    }
}

struct ReportRowView: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
        }
    }
}
