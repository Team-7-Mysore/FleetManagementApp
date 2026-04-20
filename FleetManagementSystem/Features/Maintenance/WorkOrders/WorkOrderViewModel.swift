import Foundation
import Supabase
import Combine

@MainActor
final class WorkOrderViewModel: ObservableObject {

    // MARK: - Published State
    @Published var workOrders: [WorkOrder] = []
    @Published var availableInventory: [InventoryItem] = []

    @Published var inProgressOrders: [WorkOrder] = []
    @Published var pendingOrders: [WorkOrder] = []
    @Published var completedOrders: [WorkOrder] = []

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Main Fetch
//    func fetchWorkOrders() async {
//        isLoading = true
//        errorMessage = nil
//
//        do {
//            let fetchedOrders: [WorkOrder] = try await SupabaseManager.shared.client
//                .from("work_orders")
//                .select()
//                .execute()
//                .value
//
//            self.workOrders = fetchedOrders
//            self.inProgressOrders = fetchedOrders.filter { $0.status == .inProgress }
//            self.pendingOrders = fetchedOrders.filter { $0.status == .pending }
//            self.completedOrders = fetchedOrders.filter { $0.status == .completed }
//
//        } catch {
//            print("ERROR:", error)
//            self.errorMessage = "Failed to fetch work orders: \(error.localizedDescription)"
//        }
//
//        isLoading = false
//    }

    // MARK: - Main Fetch
        func fetchWorkOrders() async {
            isLoading = true
            errorMessage = nil

            do {
                let fetchedOrders: [WorkOrder] = try await SupabaseManager.shared.client
                    .from("work_orders")
                    .select()
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                self.workOrders = fetchedOrders
                self.inProgressOrders = fetchedOrders.filter { $0.status == .inProgress }
                self.pendingOrders = fetchedOrders.filter { $0.status == .pending }
                self.completedOrders = fetchedOrders.filter { $0.status == .completed }

            } catch {
                print("ERROR:", error)
                self.errorMessage = "Failed to fetch work orders: \(error.localizedDescription)"
            }

            isLoading = false
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
