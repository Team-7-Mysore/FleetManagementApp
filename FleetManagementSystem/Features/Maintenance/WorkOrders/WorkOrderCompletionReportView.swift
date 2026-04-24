import SwiftUI
import PDFKit

struct WorkOrderCompletionReportView: View {
    @Environment(\.dismiss) private var dismiss
    let workOrder: WorkOrder
    
    @StateObject private var viewModel = WorkOrderViewModel()
    
    @State private var tasks: [WorkOrderTask] = []
    @State private var partsUI: [PartDisplayInfo] = []
    
    @State private var isLoading: Bool = true
    @State private var isUploading: Bool = false
    
    private let pageWidth: CGFloat = 595.2
    private let pageHeight: CGFloat = 841.8
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5)
                        Text("Compiling Final Report...")
                    }
                } else {
                    ScrollView {
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
                        ProgressView()
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
    
    // MARK: - REPORT CONTENT
    private var printableReportContent: some View {
        VStack(spacing: 24) {
            
            // 1. VEHICLE HEADER
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workOrder.vehicle?.vehicleName ?? "Fleet Vehicle")
                            .font(.title2).bold()
                        Text("VIN: \(workOrder.vehicle?.vin ?? "N/A")").font(.caption).foregroundColor(.secondary)
                        Text("PLATE: \(workOrder.vehicle?.numberPlate ?? "N/A")").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(workOrder.status.rawValue.uppercased())
                            .font(.caption2).bold().padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.green.opacity(0.1)).foregroundColor(.green).clipShape(Capsule())
                        
                        Text(workOrder.priority.rawValue.uppercased())
                            .font(.caption2).bold().padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1)).foregroundColor(.orange).clipShape(Capsule())
                    }
                }
                Divider()
                HStack {
                    ReportDetailColumn(title: "REPORT ID", value: "#WO-\(workOrder.workOrderId.uuidString.prefix(8).uppercased())")
                    Spacer()
                    ReportDetailColumn(title: "COMPLETION DATE", value: workOrder.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "N/A")
                }
            }
            .padding().background(Color.white).cornerRadius(16)
            
            // 2. ISSUE SUMMARY (Fixed Clipping)
            ReportSectionView(title: "WORK PERFORMED") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workOrder.issueTitle)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true) // Prevents title cut-off
                    
                    if let desc = workOrder.issueDescription {
                        Text(desc)
                            .font(.subheadline).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true) // Prevents description cut-off
                    }
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .systemGray6)).cornerRadius(12)
            }
            
            // 3. TASKS
            if !tasks.isEmpty {
                ReportSectionView(title: "SERVICE TASKS") {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(tasks) { task in
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                                Text(task.description).font(.subheadline)
                                Spacer()
                            }.padding()
                            if task.id != tasks.last?.id { Divider() }
                        }
                    }.background(Color.white).cornerRadius(12)
                }
            }
            
            // 4. PARTS
            if !partsUI.isEmpty {
                ReportSectionView(title: "PARTS & MATERIALS") {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(partsUI) { part in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(part.name).font(.subheadline).bold()
                                    Text("Qty: \(part.quantity) @ ₹\(String(format: "%.2f", part.unitCost))").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("₹\(String(format: "%.2f", Double(part.quantity) * part.unitCost))").font(.subheadline).bold()
                            }.padding()
                            if part.id != partsUI.last?.id { Divider() }
                        }
                    }.background(Color.white).cornerRadius(12)
                }
            }
            
            // 5. COST METRICS (Removed "Est")
            ReportSectionView(title: "FINANCIAL SUMMARY") {
                VStack(spacing: 0) {
                    ReportRowView(label: "Labour Time", value: "\(String(format: "%.1f", workOrder.hoursWorked ?? 0.0)) Hours")
                    Divider()
                    ReportRowView(label: "Total Service Cost", value: "₹\(String(format: "%.2f", workOrder.estCost ?? 0.0))")
                        .foregroundColor(.blue)
                }
                .background(Color.white).cornerRadius(12)
            }
            
            // 6. PHOTO DOCUMENTATION (With Placeholder Fix)
            ReportSectionView(title: "PHOTO DOCUMENTATION") {
                VStack(spacing: 16) {
                    if let images = workOrder.images, !images.isEmpty {
                        ForEach(images, id: \.self) { urlString in
                            PDFImageComponent(urlString: urlString)
                        }
                    } else {
                        // Placeholder if no photos exist
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle).foregroundColor(.gray.opacity(0.4))
                            Text("No photo documentation provided for this report.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 40)
                        .background(Color.white).cornerRadius(12)
                    }
                }
            }
            
            Text("Generated on \(Date().formatted())").font(.caption2).foregroundColor(.gray)
        }
        .padding(40)
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
                        mappedParts.append(PartDisplayInfo(inventoryId: inv.inventoryId, name: inv.partName, quantity: wp.quantityRequired, unitCost: inv.costPerUnit ?? 0.0))
                    }
                }
            }
            
            await MainActor.run {
                self.tasks = fetchedTasks.filter { $0.isCompleted }
                self.partsUI = mappedParts
                self.isLoading = false
            }
            
            // IMPORTANT: Increased delay to ensure all images in the report load into cache
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { generateAndUploadPDF() }
        } catch {
            await MainActor.run { self.isLoading = false }
        }
    }
    
    // MARK: - PDF RENDERER
    @MainActor
    private func generateAndUploadPDF() {
        isUploading = true
        let controller = UIHostingController(rootView: printableReportContent.frame(width: pageWidth))
        let view = controller.view
        
        let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: pageWidth, height: pageHeight)))
        window.rootViewController = controller
        window.isHidden = true
        window.makeKeyAndVisible()
        
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
                // DrawHierarchy with afterScreenUpdates true is vital for images
                view?.drawHierarchy(in: view?.bounds ?? .zero, afterScreenUpdates: true)
                context.cgContext.restoreGState()
                currentY += pageHeight
            }
        }
        
        Task {
            do {
                let url = try await viewModel.uploadPDFReportToSupabase(pdfData: pdfData, workOrderId: workOrder.workOrderId.uuidString)
                try await viewModel.saveReportDatabaseRecord(workOrderId: workOrder.workOrderId, reportUrl: url, reportName: "Final_Report_\(workOrder.workOrderId.uuidString.prefix(6))")
                isUploading = false
                window.isHidden = true
            } catch {
                isUploading = false
            }
        }
    }
}

// MARK: - CUSTOM IMAGE COMPONENT FOR PDF
// Uses Data(contentsOf:) to force synchronous loading during PDF rendering
struct PDFImageComponent: View {
    let urlString: String
    @State private var uiImage: UIImage? = nil
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1))
                    .frame(height: 200).overlay(ProgressView())
            }
        }
        .task {
            if let url = URL(string: urlString), let data = try? Data(contentsOf: url) {
                self.uiImage = UIImage(data: data)
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
