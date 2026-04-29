import Foundation
import Supabase
import Combine
import SwiftUI

@MainActor
final class InventoryViewModel: ObservableObject {
    struct AlertItem: Identifiable {
        let id = UUID()
        let message: String
    }

    struct PartUsage: Identifiable, Equatable {
        let workOrderId: UUID
        let vehicleId: UUID
        let vehicleName: String
        let vehicleNumber: String?
        let vehicleType: String?
        let quantityUsed: Int
        let costAtTime: Double
        let workOrderReference: String
        let usedAt: Date?

        var id: String { "\(workOrderId.uuidString)-\(vehicleId.uuidString)" }
    }

    enum InventoryDeletionError: LocalizedError {
        case placeholderID(UUID)
        case noRowDeleted(UUID)

        var errorDescription: String? {
            switch self {
            case .placeholderID(let id):
                return "Refusing to delete inventory item with placeholder UUID \(id.uuidString)."
            case .noRowDeleted(let id):
                return "No inventory row matched delete request for \(id.uuidString)."
            }
        }
    }

    @Published private(set) var items: [InventoryItem] = []
    @Published var filteredItems: [InventoryItem] = []
    @Published var selectedVehicleFilter: String = "All" {
        didSet { applyFilters() }
    }
    @Published var searchText: String = "" {
        didSet { applyFilters() }
    }
    @Published var showLowStockBanner: Bool = true
    @Published var deleteErrorMessage: AlertItem?
    @Published var notifications: [NotificationItem] = []
    @Published var partUsage: [PartUsage] = []
    @Published var isLoadingPartUsage = false
    @Published private(set) var activePartUsageInventoryId: UUID?

    private let placeholderInventoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    private let supabase = SupabaseManager.shared.client
    private var inventoryCache: [UUID: InventoryItem] = [:]
    private var inventoryOrder: [UUID] = []
    private var partUsageCache: [UUID: [PartUsage]] = [:]
    private var hasLoadedInitialInventory = false
    private var inventoryRealtimeChannel: RealtimeChannelV2?
    private var inventoryRealtimeTask: Task<Void, Never>?

    var lowStockItems: [InventoryItem] {
        items.filter { item in
            guard item.quantity <= 10 else { return false }
            if selectedVehicleFilter == "All" {
                return true
            }
            return (item.vehicleCategory ?? "") == selectedVehicleFilter
        }
    }

    var hasLowStock: Bool {
        !lowStockItems.isEmpty
    }

    func fetchInventory(forceRefresh: Bool = false) async {
        await startInventoryRealtimeIfNeeded()

        if forceRefresh {
            clearInventoryCache()
        } else if hasLoadedInitialInventory {
            applyInventorySnapshot()
            return
        }

        do {
            let fetchedItems: [InventoryItem] = try await supabase
                .from("inventory")
                .select()
                .execute()
                .value

            let sanitizedItems = fetchedItems.filter { $0.inventoryId != placeholderInventoryID }
            rebuildInventoryCache(with: sanitizedItems)
            hasLoadedInitialInventory = true
            applyInventorySnapshot()

            await ensureNotificationsLoaded()
            await syncLowStockNotifications()
        } catch {
            print("ERROR fetching inventory:", error)
        }
    }

    func refreshInventory() async {
        await fetchInventory(forceRefresh: true)
    }

    func clearCache() {
        clearInventoryCache()
        partUsageCache.removeAll()
        partUsage = []
        activePartUsageInventoryId = nil
        notifications = []
        hasLoadedInitialInventory = false
        applyInventorySnapshot()
    }

    func checkForDuplicate(name: String, category: String?) async -> InventoryItem? {
        items.first { item in
            item.partName.lowercased() == name.lowercased() &&
            (item.vehicleCategory ?? "").lowercased() == (category ?? "").lowercased()
        }
    }

    func combineInventoryItem(id: UUID, additionalQuantity: Int) async throws {
        guard let existingItem = inventoryCache[id] else { return }

        struct InventoryQuantityUpdate: Codable {
            let quantity: Int
            let updatedAt: String

            enum CodingKeys: String, CodingKey {
                case quantity
                case updatedAt = "updated_at"
            }
        }

        let updateData = InventoryQuantityUpdate(
            quantity: existingItem.quantity + additionalQuantity,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        _ = try await supabase
            .from("inventory")
            .update(updateData)
            .eq("inventory_id", value: id.uuidString)
            .execute()
    }

    func addInventoryItem(partName: String, vehicleCategory: String?, categoryDescription: String?, supplier: String?, quantity: Int, costPerUnit: Double?, sku: String?, location: String?, imageUrl: String?) async throws {
        let insertItem = InventoryItemInsert(
            partName: partName,
            vehicleCategory: vehicleCategory,
            categoryDescription: categoryDescription,
            supplier: supplier,
            quantity: quantity,
            costPerUnit: costPerUnit,
            sku: sku,
            location: location,
            imageUrl: imageUrl
        )

        _ = try await supabase
            .from("inventory")
            .insert(insertItem)
            .execute()
    }

    func deleteInventoryItem(id: UUID) async throws {
        deleteErrorMessage = nil

        if id == placeholderInventoryID {
            throw InventoryDeletionError.placeholderID(id)
        }

        do {
            let deletedRows: [DeletedInventoryRow] = try await supabase
                .from("inventory")
                .delete()
                .eq("inventory_id", value: id.uuidString)
                .select("inventory_id")
                .execute()
                .value

            guard deletedRows.contains(where: { $0.inventoryId == id }) else {
                throw InventoryDeletionError.noRowDeleted(id)
            }

            removeInventoryItem(id: id)
            await deleteNotification(forInventoryID: id)
        } catch {
            if let pgError = error as? PostgrestError, pgError.code == "23503" {
                deleteErrorMessage = AlertItem(message: "This part is used in a work order and cannot be deleted.")
            } else {
                deleteErrorMessage = AlertItem(message: "Failed to delete part. Please try again.")
            }

            print("ERROR deleting item \(id):", error)
            throw error
        }
    }

    func updateInventoryItem(id: UUID, partName: String, vehicleCategory: String?, supplier: String?, quantity: Int, costPerUnit: Double?, location: String?) async throws {
        let updateData = InventoryItemUpdate(
            partName: partName,
            vehicleCategory: vehicleCategory,
            supplier: supplier,
            quantity: quantity,
            costPerUnit: costPerUnit,
            location: location,
            updatedAt: Date()
        )

        _ = try await supabase
            .from("inventory")
            .update(updateData)
            .eq("inventory_id", value: id.uuidString)
            .execute()
    }

    func fetchNotifications() async {
        do {
            let data: [NotificationItem] = try await supabase
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            notifications = data
        } catch {
            print("Error fetching notifications:", error)
        }
    }

    func syncLowStockNotifications() async {
        await ensureNotificationsLoaded()
        for item in items {
            await syncNotification(for: item, previousItem: nil)
        }
    }

    func fetchPartUsage(inventoryId: UUID, useCache: Bool = true) async throws -> [PartUsage] {
        activePartUsageInventoryId = inventoryId

        if useCache, let cached = partUsageCache[inventoryId] {
            partUsage = cached
            return cached
        }

        isLoadingPartUsage = true
        defer { isLoadingPartUsage = false }

        print("🔎 fetchPartUsage inventory_id:", inventoryId.uuidString)

        let rows: [PartUsageRow] = try await supabase
            .from("work_order_parts")
            .select("work_order_id, inventory_id, quantity_required, cost_at_time, work_orders(work_order_id, vehicle_id, created_at, updated_at, vehicles(vehicle_id, vin, number_plate, vehicle_name, vehicle_type))")
            .eq("inventory_id", value: inventoryId.uuidString)
            .execute()
            .value

        print("🔎 work_order_parts rows fetched:", rows.count)
        for row in rows {
            print("🔎 usage row workOrderId=\(row.workOrderId.uuidString) inventoryId=\(row.inventoryId.uuidString) quantity=\(row.quantityRequired)")
        }

        let usage = rows.compactMap { row -> PartUsage? in
            guard let workOrder = row.workOrder,
                  let vehicle = workOrder.vehicle else {
                return nil
            }

            let vehicleName = vehicle.vehicleName ?? vehicle.numberPlate ?? "Unknown Vehicle"
            let vehicleId = workOrder.vehicleId ?? vehicle.vehicleId

            return PartUsage(
                workOrderId: row.workOrderId,
                vehicleId: vehicleId,
                vehicleName: vehicleName,
                vehicleNumber: vehicle.numberPlate,
                vehicleType: vehicle.vehicleType?.rawValue,
                quantityUsed: row.quantityRequired,
                costAtTime: row.costAtTime ?? 0,
                workOrderReference: "WO-\(row.workOrderId.uuidString.prefix(6).uppercased())",
                usedAt: workOrder.updatedAt ?? workOrder.createdAt
            )
        }
        .sorted {
            switch ($0.usedAt, $1.usedAt) {
            case let (lhs?, rhs?):
                return lhs > rhs
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return $0.workOrderReference > $1.workOrderReference
            }
        }

        partUsageCache[inventoryId] = usage
        if activePartUsageInventoryId == inventoryId {
            partUsage = usage
        }
        return usage
    }

    func cachedPartUsage(for inventoryId: UUID) -> [PartUsage]? {
        partUsageCache[inventoryId]
    }

    func cachedTotalUsed(for inventoryId: UUID) -> Int {
        partUsageCache[inventoryId]?.reduce(0) { $0 + $1.quantityUsed } ?? 0
    }

    func uploadImage(data: Data, fileName: String) async throws -> String {
        let path = "part-images/\(fileName)"

        _ = try await supabase
            .storage
            .from("inventory-images")
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: "image/jpeg")
            )

        let publicURL = try supabase
            .storage
            .from("inventory-images")
            .getPublicURL(path: path)

        return publicURL.absoluteString
    }
}

private extension InventoryViewModel {
    func startInventoryRealtimeIfNeeded() async {
        guard inventoryRealtimeChannel == nil else { return }

        let channel = supabase.realtimeV2.channel("inventory-realtime")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "inventory")

        do {
            try await channel.subscribe()
            inventoryRealtimeChannel = channel
            inventoryRealtimeTask = Task { [weak self] in
                guard let self else { return }
                for await action in changes {
                    await self.handleInventoryRealtime(action: action)
                }
            }
        } catch {
            print("🚨 Inventory realtime subscription failed:", error)
        }
    }

    func handleInventoryRealtime(action: AnyAction) async {
        switch action {
        case .insert(let action):
            if let item = try? action.decodeRecord(as: InventoryItem.self, decoder: Self.makeDecoder()) {
                upsertInventoryItem(item, insertingAtFront: true)
                await syncNotification(for: item, previousItem: nil)
            }
        case .update(let action):
            if let item = try? action.decodeRecord(as: InventoryItem.self, decoder: Self.makeDecoder()) {
                let previous = inventoryCache[item.inventoryId]
                upsertInventoryItem(item, insertingAtFront: false)
                await syncNotification(for: item, previousItem: previous)
            }
        case .delete(let action):
            guard let rawID = action.oldRecord["inventory_id"]?.stringValue,
                  let inventoryId = UUID(uuidString: rawID) else { return }
            removeInventoryItem(id: inventoryId)
            await deleteNotification(forInventoryID: inventoryId)
        default:
            break
        }
    }

    func rebuildInventoryCache(with fetchedItems: [InventoryItem]) {
        inventoryCache = Dictionary(uniqueKeysWithValues: fetchedItems.map { ($0.inventoryId, $0) })
        inventoryOrder = fetchedItems.map(\.inventoryId)
    }

    func clearInventoryCache() {
        inventoryCache.removeAll()
        inventoryOrder.removeAll()
        items = []
        filteredItems = []
    }

    func upsertInventoryItem(_ item: InventoryItem, insertingAtFront: Bool) {
        guard item.inventoryId != placeholderInventoryID else { return }

        let exists = inventoryCache[item.inventoryId] != nil
        inventoryCache[item.inventoryId] = item

        if exists {
            if !inventoryOrder.contains(item.inventoryId) {
                inventoryOrder.insert(item.inventoryId, at: 0)
            }
        } else if insertingAtFront {
            inventoryOrder.insert(item.inventoryId, at: 0)
        } else {
            inventoryOrder.append(item.inventoryId)
        }

        applyInventorySnapshot()
    }

    func removeInventoryItem(id: UUID) {
        inventoryCache.removeValue(forKey: id)
        inventoryOrder.removeAll { $0 == id }
        partUsageCache.removeValue(forKey: id)

        if activePartUsageInventoryId == id {
            activePartUsageInventoryId = nil
            partUsage = []
        }

        applyInventorySnapshot()
    }

    func applyInventorySnapshot() {
        items = inventoryOrder.compactMap { inventoryCache[$0] }
        applyFilters()
    }

    func applyFilters() {
        var result = items

        if selectedVehicleFilter != "All" {
            result = result.filter { ($0.vehicleCategory ?? "") == selectedVehicleFilter }
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            let lowercasedSearch = trimmedSearch.lowercased()
            result = result.filter { item in
                let matchName = item.partName.lowercased().contains(lowercasedSearch)
                let matchSKU = item.sku?.lowercased().contains(lowercasedSearch) ?? false
                let matchCategory = item.vehicleCategory?.lowercased().contains(lowercasedSearch) ?? false
                let matchDesc = item.categoryDescription?.lowercased().contains(lowercasedSearch) ?? false
                return matchName || matchSKU || matchCategory || matchDesc
            }
        }

        filteredItems = result
    }

    func ensureNotificationsLoaded() async {
        if notifications.isEmpty {
            await fetchNotifications()
        }
    }

    func syncNotification(for item: InventoryItem, previousItem: InventoryItem?) async {
        let wasLowStock = previousItem?.quantity ?? Int.max
        let isLowStock = item.quantity <= 10
        let existedNotification = notifications.first(where: { $0.inventoryId == item.inventoryId })

        if isLowStock {
            if let existing = existedNotification {
                if existing.message != lowStockMessage(for: item) {
                    await updateNotification(existing, for: item)
                }
            } else {
                let didCreate = await createNotification(for: item)
                if didCreate && wasLowStock > 10 {
                    NotificationManager.shared.sendLowStockNotification(
                        partName: item.partName,
                        quantity: item.quantity
                    )
                }
            }
        } else if existedNotification != nil {
            await deleteNotification(forInventoryID: item.inventoryId)
        }
    }

    func createNotification(for item: InventoryItem) async -> Bool {
        guard !notifications.contains(where: { $0.inventoryId == item.inventoryId }) else {
            return false
        }

        do {
            let payload = LowStockNotificationPayload(
                inventory_id: item.inventoryId,
                title: "Low Stock Alert",
                message: lowStockMessage(for: item)
            )

            let created: [NotificationItem] = try await supabase
                .from("notifications")
                .insert(payload)
                .select()
                .execute()
                .value

            if let notification = created.first {
                notifications.insert(notification, at: 0)
            }
            return true
        } catch {
            print("Insert notification error:", error)
            return false
        }
    }

    func updateNotification(_ notification: NotificationItem, for item: InventoryItem) async {
        let payload = LowStockNotificationUpdatePayload(message: lowStockMessage(for: item))

        do {
            let updated: [NotificationItem] = try await supabase
                .from("notifications")
                .update(payload)
                .eq("notification_id", value: notification.notificationId.uuidString)
                .select()
                .execute()
                .value

            if let updatedNotification = updated.first,
               let index = notifications.firstIndex(where: { $0.notificationId == updatedNotification.notificationId }) {
                notifications[index] = updatedNotification
            }
        } catch {
            print("Update notification error:", error)
        }
    }

    func deleteNotification(forInventoryID inventoryId: UUID) async {
        do {
            let deleted: [NotificationItem] = try await supabase
                .from("notifications")
                .delete()
                .eq("inventory_id", value: inventoryId.uuidString)
                .select()
                .execute()
                .value

            let deletedIDs = Set(deleted.map(\.notificationId))
            if deletedIDs.isEmpty {
                notifications.removeAll { $0.inventoryId == inventoryId }
            } else {
                notifications.removeAll { deletedIDs.contains($0.notificationId) }
            }
        } catch {
            print("Delete notification error:", error)
        }
    }

    func lowStockMessage(for item: InventoryItem) -> String {
        "\(item.partName) is low in stock (Qty: \(item.quantity))"
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = BackendDateParser.parse(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(raw)"
            )
        }
        return decoder
    }
}

private struct DeletedInventoryRow: Decodable {
    let inventoryId: UUID

    enum CodingKeys: String, CodingKey {
        case inventoryId = "inventory_id"
    }
}

private struct PartUsageRow: Decodable {
    let workOrderId: UUID
    let inventoryId: UUID
    let quantityRequired: Int
    let costAtTime: Double?
    let workOrder: PartUsageWorkOrder?

    enum CodingKeys: String, CodingKey {
        case workOrderId = "work_order_id"
        case inventoryId = "inventory_id"
        case quantityRequired = "quantity_required"
        case costAtTime = "cost_at_time"
        case workOrder = "work_orders"
    }
}

private struct PartUsageWorkOrder: Decodable {
    let workOrderId: UUID
    let vehicleId: UUID?
    let createdAt: Date?
    let updatedAt: Date?
    let vehicle: WorkOrderVehicle?

    enum CodingKeys: String, CodingKey {
        case workOrderId = "work_order_id"
        case vehicleId = "vehicle_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case vehicle = "vehicles"
    }
}

private struct LowStockNotificationPayload: Codable {
    let inventory_id: UUID
    let title: String
    let message: String
}

private struct LowStockNotificationUpdatePayload: Codable {
    let message: String
}

struct InventoryItemInsert: Codable {
    var partName: String
    var vehicleCategory: String?
    var categoryDescription: String?
    var supplier: String?
    var quantity: Int
    var costPerUnit: Double?
    var sku: String?
    var location: String?
    var imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case partName = "part_name"
        case vehicleCategory = "vehicle_category"
        case categoryDescription = "category_description"
        case supplier
        case quantity
        case costPerUnit = "cost_per_unit"
        case sku
        case location
        case imageUrl = "image_url"
    }
}

struct InventoryItemUpdate: Codable {
    var partName: String
    var vehicleCategory: String?
    var supplier: String?
    var quantity: Int
    var costPerUnit: Double?
    var location: String?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case partName = "part_name"
        case vehicleCategory = "vehicle_category"
        case supplier
        case quantity
        case costPerUnit = "cost_per_unit"
        case location
        case updatedAt = "updated_at"
    }
}
