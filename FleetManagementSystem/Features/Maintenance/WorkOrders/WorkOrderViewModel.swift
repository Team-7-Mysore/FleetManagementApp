import Foundation
import Supabase
import Combine

@MainActor
final class WorkOrderViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var workOrders: [WorkOrder] = []
    @Published var availableInventory: [InventoryItem] = []
    
    @Published var inProgressOrders: [WorkOrder] = []
    @Published var completedOrders: [WorkOrder] = []
    
    // Split the pending orders into two distinct lists
    @Published var waitingForApproval: [WorkOrder] = []
    @Published var approvedPending: [WorkOrder] = []
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // MARK: - Main Fetch
    func fetchWorkOrders() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedOrders: [WorkOrder] = try await SupabaseManager.shared.client
                .from("work_orders")
                .select()
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            filterOrders(fetchedOrders: fetchedOrders)
            
        } catch {
            print("ERROR:", error)
            self.errorMessage = "Failed to fetch work orders: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func filterOrders(fetchedOrders: [WorkOrder]) {
        self.workOrders = fetchedOrders
        
        // 1. Waiting for Approval: Status is Pending AND isApproved is false
        self.waitingForApproval = fetchedOrders.filter {
            $0.status == .pending && !$0.isApproved
        }
        
        // 2. Approved Pending: Status is Pending AND isApproved is true
        // This acts as the "Ready to Start" queue
        self.approvedPending = fetchedOrders.filter {
            $0.status == .pending && $0.isApproved
        }
        
        // 3. Active Work
        self.inProgressOrders = fetchedOrders.filter { $0.status == .inProgress }
        
        // 4. Archive
        self.completedOrders = fetchedOrders.filter { $0.status == .completed }
    }
    
    // MARK: - Relational Data Fetches
    func fetchTasks(for workOrderId: UUID) async throws -> [WorkOrderTask] {
        return try await SupabaseManager.shared.client
            .from("work_order_tasks")
            .select()
            .eq("work_order_id", value: workOrderId)
            .execute()
            .value
    }
    
    func fetchParts(for workOrderId: UUID) async throws -> [WorkOrderPart] {
        return try await SupabaseManager.shared.client
            .from("work_order_parts")
            .select()
            .eq("work_order_id", value: workOrderId)
            .execute()
            .value
    }
    
    func fetchInventory(for ids: [UUID]) async throws -> [InventoryItem] {
        guard !ids.isEmpty else { return [] }
        let stringIds = ids.map { $0.uuidString }
        return try await SupabaseManager.shared.client
            .from("inventory")
            .select()
            .in("inventory_id", values: stringIds)
            .execute()
            .value
    }
    
    // MARK: - Save Methods
    func upsertWorkOrder(_ workOrder: WorkOrder) async throws {
        try await SupabaseManager.shared.client
            .from("work_orders")
            .upsert(workOrder)
            .execute()
    }
    
    func insertTasks(_ tasks: [WorkOrderTask]) async throws {
        guard !tasks.isEmpty else { return }
        try await SupabaseManager.shared.client
            .from("work_order_tasks")
            .insert(tasks)
            .execute()
    }
    
    func upsertTasks(_ tasks: [WorkOrderTask]) async throws {
        guard !tasks.isEmpty else { return }
        try await SupabaseManager.shared.client
            .from("work_order_tasks")
            .upsert(tasks)
            .execute()
    }
    
    func upsertParts(_ parts: [WorkOrderPart]) async throws {
        guard !parts.isEmpty else { return }
        try await SupabaseManager.shared.client
            .from("work_order_parts")
            .upsert(parts)
            .execute()
    }
    
    func fetchAllInventory() async {
        do {
            let fetched: [InventoryItem] = try await SupabaseManager.shared.client
                .from("inventory")
                .select()
                .execute()
                .value
            
            self.availableInventory = fetched
        } catch {
            print("ERROR fetching inventory: \(error)")
        }
    }
}

// MARK: - Storage & External File Handlers
extension WorkOrderViewModel {
    
    // MARK: - Upload Image (Only uploads to bucket, DB insert handled by upsertWorkOrder)
    func uploadImageToSupabase(imageData: Data, fileName: String) async throws -> String {
        let bucket = "maintenance-images"
        let uniquePath = "work_orders/\(UUID().uuidString)-\(fileName)"
        
        // 1. Upload to bucket
        try await SupabaseManager.shared.client.storage
            .from(bucket)
            .upload(
                uniquePath,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        // 2. Retrieve public URL
        let publicURL = try SupabaseManager.shared.client.storage
            .from(bucket)
            .getPublicURL(path: uniquePath)
        
        return publicURL.absoluteString
    }
    
    // MARK: - Upload PDF Report to Bucket
    func uploadPDFReportToSupabase(pdfData: Data, workOrderId: String) async throws -> String {
        let bucket = "work-order-reports"
        let uniquePath = "reports/WO-\(workOrderId)-\(UUID().uuidString.prefix(4)).pdf"
        
        // 1. Upload to bucket using SupabaseManager
        try await SupabaseManager.shared.client.storage
            .from(bucket)
            .upload(
                uniquePath,
                data: pdfData,
                options: FileOptions(contentType: "application/pdf")
            )
        
        // 2. Retrieve public URL
        let publicURL = try SupabaseManager.shared.client.storage
            .from(bucket)
            .getPublicURL(path: uniquePath)
        
        return publicURL.absoluteString
    }
    
    // MARK: - 2. Save URL to Database Table
    func saveReportDatabaseRecord(workOrderId: UUID, reportUrl: String, reportName: String) async throws {
        
        // Define the structure matching your "reports" table in Supabase
        struct ReportRecord: Encodable {
            let work_order_id: UUID
            let report_url: String
            let report_name: String
        }
        
        let newReport = ReportRecord(
            work_order_id: workOrderId,
            report_url: reportUrl,
            report_name: reportName
        )

        try await SupabaseManager.shared.client
            .from("work_order_reports") 
            .insert(newReport)
            .execute()
    }
}

extension WorkOrderViewModel {
    
    // MARK: - Request Manager Approval Notification
    func requestManagerApproval(for workOrder: WorkOrder, mechanicId: UUID, managerId: UUID) async {
        
        let vehicleName = workOrder.vehicleName ?? "a vehicle"
        let shortId = workOrder.workOrderId.uuidString.prefix(6).uppercased()
        
        // Create the DTO matching our exact finalized schema
        let insertData = NotificationInsertDTO(
            recipient_id: managerId,
            sender_id: mechanicId,
            title: "Approval Required",
            message: "Work Order #WO-\(shortId) for \(vehicleName) has been drafted and requires your approval.",
            type: NotificationType.maintenance.rawValue, // Grouped under maintenance as you requested!
            related_entity_id: workOrder.workOrderId
        )
        
        do {
            try await SupabaseManager.shared.client
                .from("notifications")
                .insert(insertData)
                .execute()
            
            print("Approval notification successfully sent to Fleet Manager!")
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
}
