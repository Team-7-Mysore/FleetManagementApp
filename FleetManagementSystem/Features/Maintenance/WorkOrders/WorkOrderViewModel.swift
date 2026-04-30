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
    func fetchWorkOrders(profile: UserProfile?) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Start building the query
            var query = SupabaseManager.shared.client
                .from("work_orders")
                .select("*, vehicles(vehicle_id, vin, number_plate, vehicle_name, vehicle_type)")
            
            if let userProfile = profile, userProfile.role.rawValue.lowercased() == "maintenance" {
                query = query.eq("maintenance_personnel_id", value: userProfile.userId.uuidString)
            }
            
            // 3. Execute the query
            let fetchedOrders: [WorkOrder] = try await query
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
        
        // Use ?? false to default to false if the value is missing
        self.waitingForApproval = fetchedOrders.filter {
            $0.status == .pending && ($0.isApproved) == false
        }
        
        self.approvedPending = fetchedOrders.filter {
            $0.status == .pending && ($0.isApproved) == true
        }
        
        self.inProgressOrders = fetchedOrders
            .filter { $0.status == .inProgress }
            .sorted { $0.createdAt! > $1.createdAt! }
        
        self.completedOrders = fetchedOrders
            .filter { $0.status == .completed }
            .sorted { $0.createdAt! > $1.createdAt! }
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
        do {
            try await SupabaseManager.shared.client
                .from("work_order_parts")
                .upsert(parts)
                .execute()
        } catch {
            print("⚠️ upsertParts with used_at failed, retrying legacy payload:", error)
            let legacyPayloads = parts.map { part in
                WorkOrderPartLegacyPayload(
                    workOrderId: part.workOrderId,
                    inventoryId: part.inventoryId,
                    quantityRequired: part.quantityRequired,
                    costAtTime: part.costAtTime
                )
            }
            
            try await SupabaseManager.shared.client
                .from("work_order_parts")
                .upsert(legacyPayloads)
                .execute()
        }
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
    
    // Explicitly delete a task from Supabase
    func deleteTask(taskId: UUID) async throws {
        try await SupabaseManager.shared.client
            .from("work_order_tasks")
            .delete()
            .eq("task_id", value: taskId.uuidString)
            .execute()
    }
    
    // Explicitly delete a part from Supabase
    func deletePart(workOrderId: UUID, inventoryId: UUID) async throws {
        try await SupabaseManager.shared.client
            .from("work_order_parts")
            .delete()
            .eq("work_order_id", value: workOrderId.uuidString)
            .eq("inventory_id", value: inventoryId.uuidString)
            .execute()
    }
    
    // Explicitly delete an entire work order from Supabase
    func deleteWorkOrder(_ workOrderId: UUID) async throws {
        let idStr = workOrderId.uuidString
        
        // 1. Delete dependent Tasks (solves foreign key constraint)
        try? await SupabaseManager.shared.client
            .from("work_order_tasks")
            .delete()
            .eq("work_order_id", value: idStr)
            .execute()
        
        // 2. Delete dependent Parts
        try? await SupabaseManager.shared.client
            .from("work_order_parts")
            .delete()
            .eq("work_order_id", value: idStr)
            .execute()
        
        // 3. Delete any dependent Notifications
        try? await SupabaseManager.shared.client
            .from("notifications")
            .delete()
            .eq("related_entity_id", value: idStr)
            .execute()
        
        // 4. Finally, delete the actual Work Order!
        try await SupabaseManager.shared.client
            .from("work_orders")
            .delete()
            .eq("work_order_id", value: idStr)
            .execute()
    }
}

private struct WorkOrderPartLegacyPayload: Encodable {
    let workOrderId: UUID
    let inventoryId: UUID
    let quantityRequired: Int
    let costAtTime: Double?

    enum CodingKeys: String, CodingKey {
        case workOrderId = "work_order_id"
        case inventoryId = "inventory_id"
        case quantityRequired = "quantity_required"
        case costAtTime = "cost_at_time"
    }
}

// Models to fetch past history
struct PastMaintenanceRecord: Codable {
    let issueTitle: String
    let issueDescription: String?
    let maintenanceNotes: String?
    let createdAt: Date
    let tasks: [PastTaskRecord]?
    
    enum CodingKeys: String, CodingKey {
        case issueTitle = "issue_title"
        case issueDescription = "issue_description"
        case maintenanceNotes = "maintenance_notes"
        case createdAt = "created_at"
        case tasks = "work_order_tasks"
    }
}

struct PastTaskRecord: Codable {
    let description: String
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

        let vehicleName = workOrder.vehicle?.vehicleName ?? workOrder.vehicle?.numberPlate ?? "a vehicle"
        let shortId = workOrder.workOrderId.uuidString.prefix(6).uppercased()

        // Create the DTO matching our exact finalized schema
        let insertData = NotificationInsertDTO(
            recipient_id: managerId,
            sender_id: mechanicId,
            title: "Approval Required",
            message: "Work Order #WO-\(shortId) for \(vehicleName) has been drafted and requires your approval.",
            type: NotificationType.maintenance.rawValue,
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
    
    // Fetches past work orders and returns a raw text string of the history
    func fetchVehicleHistoryContext(vehicleId: UUID, currentWorkOrderId: UUID) async throws -> String {
        let pastOrders: [PastMaintenanceRecord] = try await SupabaseManager.shared.client
            .from("work_orders")
            .select("issue_title, issue_description, maintenance_notes, created_at, work_order_tasks(description)")
            .eq("vehicle_id", value: vehicleId.uuidString)
            .eq("status", value: "completed") // adjust capitalization if needed
            .neq("work_order_id", value: currentWorkOrderId.uuidString)
            .order("created_at", ascending: false)
            .limit(5)
            .execute()
            .value
        
        guard !pastOrders.isEmpty else { return "" }
        
        var context = ""
        for (index, order) in pastOrders.enumerated() {
            context += "--- Past Work Order \(index + 1) ---\n"
            context += "Issue: \(order.issueTitle)\n"
            if let desc = order.issueDescription, !desc.isEmpty { context += "Description: \(desc)\n" }
            if let notes = order.maintenanceNotes, !notes.isEmpty { context += "Mechanic Notes: \(notes)\n" }
            
            if let tasks = order.tasks, !tasks.isEmpty {
                let taskList = tasks.map { "- \($0.description)" }.joined(separator: "\n")
                context += "Tasks Completed:\n\(taskList)\n"
            }
            context += "\n"
        }
        return context
    }
}


