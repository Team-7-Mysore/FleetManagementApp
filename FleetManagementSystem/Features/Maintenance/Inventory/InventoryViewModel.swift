import Foundation
import Supabase
import Combine
import SwiftUI

// Temporary initialized client assuming standard setup.
// Replace with shared instance if your project centralizes this.
@MainActor
final class InventoryViewModel: ObservableObject {
    struct AlertItem: Identifiable {
        let id = UUID()
        let message: String
    }
    
    private struct DeletedInventoryRow: Decodable {
        let inventoryId: UUID
        
        enum CodingKeys: String, CodingKey {
            case inventoryId = "inventory_id"
        }
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
    
    @Published var items: [InventoryItem] = []
    @Published var filteredItems: [InventoryItem] = []
    
    @Published var selectedVehicleFilter: String = "All" {
        didSet { filterItems() }
    }
    
    @Published var searchText: String = "" {
        didSet { filterItems() }
    }
    
    @Published var showLowStockBanner: Bool = true
    @Published var deleteErrorMessage: AlertItem?
    @Published var notifications: [NotificationItem] = []
    
    
    private let placeholderInventoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    
    private var deletedInventoryIDs = Set<UUID>()
    
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
    
    func fetchInventory() async {
        do {
            let fetchedItems: [InventoryItem] = try await SupabaseManager.shared.client
                .from("inventory")
                .select()
                .execute()
                .value
            
            let invalidItems = fetchedItems.filter { $0.inventoryId == placeholderInventoryID }
            if !invalidItems.isEmpty {
                print("INVALID INVENTORY UUIDS:", invalidItems.map(\.inventoryId))
            }
            
            let sanitizedItems = fetchedItems.filter { item in
                item.inventoryId != placeholderInventoryID &&
                !deletedInventoryIDs.contains(item.inventoryId)
            }
            
            print("DECODED COUNT:", fetchedItems.count)
            print("Fetched items:", sanitizedItems.count)
            
            self.items = sanitizedItems
            self.filterItems()
        } catch {
            print("ERROR:", error)
        }
    }
    
    func filterItems() {
        var result = items
        
        if selectedVehicleFilter != "All" {
            result = result.filter {
                ($0.vehicleCategory ?? "") == selectedVehicleFilter
            }
        }
        
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespaces)
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
        
        self.filteredItems = result
        print("All items:", items.map(\.partName))
        print("Filtered items:", filteredItems.map(\.partName))
    }
    
    func checkForDuplicate(name: String, category: String?) async -> InventoryItem? {
        return items.first { item in
            item.partName.lowercased() == name.lowercased() &&
            (item.vehicleCategory ?? "").lowercased() == (category ?? "").lowercased()
        }
    }
    
    func combineInventoryItem(id: UUID, additionalQuantity: Int) async throws {
        guard let existingItem = items.first(where: { $0.inventoryId == id }) else { return }
        
        let newQuantity = existingItem.quantity + additionalQuantity
        
        struct InventoryQuantityUpdate: Codable {
            let quantity: Int
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case quantity
                case updatedAt = "updated_at"
            }
        }
        
        let updateData = InventoryQuantityUpdate(
            quantity: newQuantity,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        _ = try await SupabaseManager.shared.client
            .from("inventory")
            .update(updateData)
            .eq("inventory_id", value: id.uuidString)
            .execute()
        
        await fetchInventory()
        await syncLowStockNotifications()
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
        
        _ = try await SupabaseManager.shared.client
            .from("inventory")
            .insert(insertItem)
            .execute()
        
        await fetchInventory()
        await syncLowStockNotifications()
    }
    
    
    func deleteInventoryItem(id: UUID) async throws {
        print("Attempting delete id:", id.uuidString)
        print("Deleting ID:", id.uuidString)
        deleteErrorMessage = nil
        
        if id == placeholderInventoryID {
            print("DELETE FAILED: placeholder UUID", id.uuidString)
            throw InventoryDeletionError.placeholderID(id)
        }
        
        do {
            let deletedRows: [DeletedInventoryRow] = try await SupabaseManager.shared.client
                .from("inventory")
                .delete()
                .eq("inventory_id", value: id.uuidString)
                .select("inventory_id")
                .execute()
                .value
            
            print("DELETE RESPONSE:", deletedRows)
            print("DELETED ROWS:", deletedRows.map(\.inventoryId))
            
            guard deletedRows.contains(where: { $0.inventoryId == id }) else {
                print("DELETE FAILED FOR ID:", id.uuidString)
                throw InventoryDeletionError.noRowDeleted(id)
            }
            
            deletedInventoryIDs.insert(id)
            
            withAnimation(.spring()) {
                self.items.removeAll { $0.inventoryId == id }
                self.filterItems()
            }
            
            await fetchNotifications()
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
        
        _ = try await SupabaseManager.shared.client
            .from("inventory")
            .update(updateData)
            .eq("inventory_id", value: id.uuidString)
            .execute()
        
        await fetchInventory()
        await syncLowStockNotifications()
    }
    
    
    
    func fetchNotifications() async {
        do {
            let data: [NotificationItem] = try await SupabaseManager.shared.client
                .from("notifications")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            self.notifications = data
        } catch {
            print("Error fetching notifications:", error)
        }
    }
    
    func createNotification(for item: InventoryItem) async -> Bool {
        if notifications.contains(where: { $0.inventoryId == item.inventoryId }) {
            return false
        }
        
        do {
            let newNotification = [
                "inventory_id": item.inventoryId.uuidString,
                "title": "Low Stock Alert",
                "message": "\(item.partName) is low in stock (Qty: \(item.quantity))"
            ]
            
            try await SupabaseManager.shared.client
                .from("notifications")
                .insert(newNotification)
                .execute()
            
            return true
        } catch {
            print("Insert notification error:", error)
            return false
        }
    }
    
    func deleteNotification(for item: InventoryItem) async {
        do {
            try await SupabaseManager.shared.client
                .from("notifications")
                .delete()
                .eq("inventory_id", value: item.inventoryId.uuidString)
                .execute()
        } catch {
            print("Delete notification error:", error)
        }
    }
    
    func syncLowStockNotifications() async {
        await fetchNotifications()
        
        for item in items {
            if item.quantity <= 10 {
                let didCreateNotification = await createNotification(for: item)
                
                if didCreateNotification {
                    NotificationManager.shared.sendLowStockNotification(
                        partName: item.partName,
                        quantity: item.quantity
                    )
                }
            } else {
                await deleteNotification(for: item)
            }
        }
        
        await fetchNotifications()
    }
    
    
    // MARK: - Image Upload (Supabase Storage)
    func uploadImage(data: Data, fileName: String) async throws -> String {
        let path = "part-images/\(fileName)"
        
        // Upload to Supabase Storage
        _ = try await SupabaseManager.shared.client
            .storage
            .from("inventory-images")
            .upload(
                path: path,
                file: data,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        // Get public URL (non-throwing)
        let publicURL = try SupabaseManager.shared.client
            .storage
            .from("inventory-images")
            .getPublicURL(path: path)
        
        return publicURL.absoluteString
    }
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
