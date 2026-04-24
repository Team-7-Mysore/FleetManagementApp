import SwiftUI
import PDFKit

// MARK: - Final Comprehensive Work Order Report View
struct WorkOrderCompletionReportView: View {
    @Environment(\.dismiss) private var dismiss
    let workOrder: WorkOrder
    
    @StateObject private var viewModel = WorkOrderViewModel()
    
    @State private var tasks: [WorkOrderTask] = []
    @State private var partsUI: [PartDisplayInfo] = []
    
    @State private var isLoading: Bool = true
    @State private var isUploading: Bool = false
    
    // A4 Paper standard dimensions (Points)
    private let pageWidth: CGFloat = 595.2
    private let pageHeight: CGFloat = 841.8
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5)
                        Text("Compiling Full Service History...")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        // This is the preview the user sees on the iPhone screen
                        printableReportContent
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Service Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isUploading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Saving PDF...").font(.caption).foregroundColor(.secondary)
                        }
                    } else {
                        Button("Done") { dismiss() }.fontWeight(.bold)
                    }
                }
            }
            .task {
                await fetchReportData()
            }
        }
    }
    
    // MARK: - COMPLETE REPORT LAYOUT
    // This VStack contains every single piece of data from your models.
    private var printableReportContent: some View {
        VStack(spacing: 24) {
            
            // 1. HEADER: Vehicle & Priority
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(workOrder.vehicle?.vehicleName ?? "Unknown Vehicle",
                              systemImage: workOrder.vehicle?.vehicleType?.sfSymbol ?? "car.fill")
                        .font(.headline)
                        
                        Text("VIN: \(workOrder.vehicle?.vin ?? "N/A")")
                        Text("PLATE: \(workOrder.vehicle?.numberPlate ?? "N/A")")
                    }
                    .font(.caption).foregroundColor(.secondary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(workOrder.status.rawValue.uppercased())
                            .font(.caption2).bold().padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.green.opacity(0.1)).foregroundColor(.green).clipShape(Capsule())
                        
                        Text(workOrder.priority.rawValue.uppercased())
                            .font(.caption2).bold().padding(.horizontal, 8).padding(.vertical, 4)
                            .background(workOrder.priority == .urgent ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
                            .foregroundColor(workOrder.priority == .urgent ? .red : .orange).clipShape(Capsule())
                    }
                }
                
                Divider()
                
                HStack {
                    ReportDetailColumn(title: "REPORT ID", value: "#WO-\(workOrder.workOrderId.uuidString.prefix(8).uppercased())")
                    Spacer()
                    ReportDetailColumn(title: "DATE COMPLETED", value: workOrder.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "N/A")
                }
            }
            .padding().background(Color(uiColor: .systemBackground)).cornerRadius(16)
            
            // 2. ISSUE SUMMARY
            ReportSectionView(title: "COMPLAINT / ISSUE") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workOrder.issueTitle).font(.headline)
                    if let desc = workOrder.issueDescription {
                        Text(desc).font(.subheadline).foregroundColor(.secondary)
                    }
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .systemGray6)).cornerRadius(12)
            }
            
            // 3. TASKS PERFORMED
            if !tasks.isEmpty {
                ReportSectionView(title: "LABOUR & SERVICE TASKS") {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(tasks) { task in
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                                Text(task.description).font(.subheadline)
                                Spacer()
                            }
                            .padding()
                            if task.id != tasks.last?.id { Divider() }
                        }
                    }
                    .background(Color(uiColor: .systemBackground)).cornerRadius(12)
                }
            }
            
            // 4. PARTS INSTALLED
            if !partsUI.isEmpty {
                ReportSectionView(title: "PARTS & MATERIALS") {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(partsUI) { part in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(part.name).font(.subheadline).bold()
                                    Text("Qty: \(part.quantity) @ ₹\(String(format: "%.2f", part.unitCost))").font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("₹\(String(format: "%.2f", Double(part.quantity) * part.unitCost))").font(.subheadline).bold()
                            }
                            .padding()
                            if part.id != partsUI.last?.id { Divider() }
                        }
                    }
                    .background(Color(uiColor: .systemBackground)).cornerRadius(12)
                }
            }
            
            // 5. FINANCIALS & METRICS
            ReportSectionView(title: "SERVICE METRICS") {
                VStack(spacing: 0) {
                    ReportRowView(label: "Time Spent", value: "\(String(format: "%.1f", workOrder.hoursWorked ?? 0.0)) Hours")
                    Divider()
                    ReportRowView(label: "Grand Total (Est.)", value: "₹\(String(format: "%.2f", workOrder.estCost ?? 0.0))")
                        .foregroundColor(.blue)
                }
                .background(Color(uiColor: .systemBackground)).cornerRadius(12)
            }
            
            // 6. NOTES (Maintenance + Internal)
            ReportSectionView(title: "REMARKS") {
                VStack(alignment: .leading, spacing: 12) {
                    if let mNotes = workOrder.maintenanceNotes {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MECHANIC NOTES").font(.caption2).bold().foregroundColor(.secondary)
                            Text(mNotes).font(.subheadline)
                        }
                    }
                    
                    if let iNotes = workOrder.internalNotes {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("INTERNAL OFFICE NOTES").font(.caption2).bold().foregroundColor(.secondary)
                            Text(iNotes).font(.subheadline).italic()
                        }
                    }
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .systemBackground)).cornerRadius(12)
            }
            
            // 7. PHOTO DOCUMENTATION
            if let images = workOrder.images, !images.isEmpty {
                ReportSectionView(title: "ATTACHED DOCUMENTATION") {
                    VStack(spacing: 16) {
                        ForEach(images, id: \.self) { urlString in
                            AsyncImage(url: URL(string: urlString)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1))
                                    .frame(height: 200).overlay(ProgressView())
                            }
                            .cornerRadius(12)
                        }
                    }
                }
            }
            
            Text("This is an electronically generated report.").font(.caption2).foregroundColor(.gray).padding(.top, 20)
        }
        .padding(40) // Standard PDF Margins
    }
    
    // MARK: - DATA FETCHING
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
            
            // Wait for AsyncImages to trigger/load and SwiftUI to settle
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            
            await MainActor.run {
                generateAndUploadPDF()
            }
            
        } catch {
            print("🚨 Failed to gather report data: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
    
    // MARK: - PDF RENDERER (OFF-SCREEN WINDOW FIX)
    @MainActor
    private func generateAndUploadPDF() {
        isUploading = true
        
        // Setup Controller
        let controller = UIHostingController(rootView: printableReportContent.frame(width: pageWidth))
        let view = controller.view
        
        // FIX: The "Blank Page" issue is solved by attaching the view to a window
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: pageWidth, height: pageHeight)))
        window.rootViewController = controller
        window.isHidden = true
        window.makeKeyAndVisible()
        
        // Calculate dynamic height for multi-page support
        let targetSize = CGSize(width: pageWidth, height: .greatestFiniteMagnitude)
        let totalHeight = view?.sizeThatFits(targetSize).height ?? pageHeight
        view?.bounds = CGRect(origin: .zero, size: CGSize(width: pageWidth, height: totalHeight))
        
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        let pdfData = renderer.pdfData { context in
            var currentY: CGFloat = 0
            while currentY < totalHeight {
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: -currentY)
                
                // Use drawHierarchy (more reliable for SwiftUI)
                view?.drawHierarchy(in: view?.bounds ?? .zero, afterScreenUpdates: true)
                
                context.cgContext.restoreGState()
                currentY += pageHeight
            }
        }
        
        // Upload to Supabase
        Task {
            do {
                let uploadedURL = try await viewModel.uploadPDFReportToSupabase(
                    pdfData: pdfData,
                    workOrderId: workOrder.workOrderId.uuidString
                )
                
                try await viewModel.saveReportDatabaseRecord(
                    workOrderId: workOrder.workOrderId,
                    reportUrl: uploadedURL,
                    reportName: "Final_Service_Report_\(workOrder.workOrderId.uuidString.prefix(6))"
                )
                
                print("✅ Full Report successfully uploaded: \(uploadedURL)")
                isUploading = false
                window.isHidden = true // Clean up
            } catch {
                print("🚨 Failed PDF Process: \(error)")
                isUploading = false
            }
        }
    }
}

// MARK: - SHARED COMPONENTS
struct ReportDetailColumn: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).bold().foregroundColor(.secondary)
            Text(value).font(.subheadline).fontWeight(.semibold)
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
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption).bold().foregroundColor(.secondary).tracking(1.0)
            content
        }
    }
}

struct ReportRowView: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).bold()
        }.padding()
    }
}
