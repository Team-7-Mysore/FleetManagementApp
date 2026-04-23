import SwiftUI

struct WorkOrderCompletionReportView: View {
    @Environment(\.dismiss) private var dismiss
    let workOrder: WorkOrder
    
    // ViewModel to fetch the tasks and parts
    @StateObject private var viewModel = WorkOrderViewModel()
    
    @State private var tasks: [WorkOrderTask] = []
    @State private var partsUI: [PartDisplayInfo] = []
    
    @State private var isLoading: Bool = true
    @State private var isUploading: Bool = false // Tracks PDF generation & upload state
    
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
                        // Display the isolated report content on the screen
                        printableReportContent
                    }
                }
            }
            .navigationTitle("Work Order Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Shows a spinner while the auto-upload is happening in the background
                        if isUploading {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Saving...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Dismiss Button
                        Button(action: { dismiss() }) {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .task {
                await fetchReportData()
            }
        }
    }
    
    // MARK: - The View to be Printed
    private var printableReportContent: some View {
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
            }
            
            // MARK: - 5. Service Metrics & Notes
            ReportSectionView(title: "SERVICE METRICS") {
                VStack(spacing: 0) {
                    ReportRowView(label: "Hours Worked", value: String(format: "%.1f hrs", workOrder.hoursWorked ?? 0.0))
                        .padding()
                    Divider().padding(.leading, 16)
                    ReportRowView(label: "Estimated Cost", value: String(format: "₹%.2f", workOrder.estCost ?? 0.0))
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
        // DO NOT add strict frames here so it looks good on an iPhone screen while scrolling.
        // We will force the A4 frame mathematically inside the renderer function below!
    }
    
    // MARK: - FIXED PDF Generation & Upload Logic
    @MainActor
    private func generateAndUploadPDF() {
        isUploading = true
        
        // 1. Enforce strict A4 Paper dimensions (595 x 842 points) and add safe area margins
        let a4SizedReport = printableReportContent
            .padding(40)
            .frame(width: 595, height: 842, alignment: .top)
            .background(Color(uiColor: .systemGroupedBackground))
        
        // 2. Setup the SwiftUI View Renderer
        let renderer = ImageRenderer(content: a4SizedReport)
        
        // 3. FIX: Use NSMutableData which bridges automatically to CFMutableData without '&'
        let pdfData = NSMutableData()
        
        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            
            // Pass the pdfData directly, no '&' needed anymore!
            guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData)!, mediaBox: &box, nil) else {
                return
            }
            
            pdfContext.beginPDFPage(nil)
            context(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }
        
        // 4. Upload to Supabase
        Task {
            do {
                // Convert the NSMutableData back to standard Swift Data for the upload
                let finalDataToUpload = pdfData as Data
                
                // A) Upload raw data to the Bucket
                let uploadedURL = try await viewModel.uploadPDFReportToSupabase(
                    pdfData: finalDataToUpload,
                    workOrderId: workOrder.workOrderId.uuidString
                )
                
                // B) Log URL to database (So the fleet manager can fetch it later)
                try await viewModel.saveReportDatabaseRecord(
                    workOrderId: workOrder.workOrderId,
                    reportUrl: uploadedURL,
                    reportName: "Completion Report - \(workOrder.workOrderId.uuidString.prefix(6))"
                )
                
                print("✅ PDF successfully generated, formatted, and saved! URL: \(uploadedURL)")
                isUploading = false
            } catch {
                print("🚨 Failed to upload PDF or save to database: \(error)")
                isUploading = false
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
            
            // 🚀 NEW: AUTO-UPLOAD LOGIC
            // Give SwiftUI a tiny fraction of a second to render the text on screen,
            // then automatically snap the PDF and upload it to Supabase!
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                generateAndUploadPDF()
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("VEHICLE ASSET")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    // UPDATED: Pull from nested vehicle object
                    Text(workOrder.vehicle?.vehicleName ?? workOrder.vehicle?.numberPlate ?? "Fleet Vehicle")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // UPDATED: Using numberPlate instead of the dropped fleetUnitId
                    Text("PLATE: \(workOrder.vehicle?.numberPlate ?? "N/A")")
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
                
                ReportDetailColumn(
                    title: "VIN",
                    value: workOrder.vehicle?.vin ?? "N/A" // UPDATED
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
