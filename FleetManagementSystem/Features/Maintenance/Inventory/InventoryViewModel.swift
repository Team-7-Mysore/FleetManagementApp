import Foundation
import Supabase
import Combine

// Temporary initialized client assuming standard setup.
// Replace with shared instance if your project centralizes this.
@MainActor
final class InventoryViewModel: ObservableObject {
    @Published var items: [InventoryItem] = []
    @Published var filteredItems: [InventoryItem] = []
    
    @Published var selectedVehicleFilter: String = "All" {
        didSet { filterItems() }
    }
    
    @Published var searchText: String = "" {
        didSet { filterItems() }
    }
    
    @Published var showLowStockBanner: Bool = true
    
    var lowStockItemsCount: Int {
        items.filter { $0.quantity <= 10 }.count
    }
    
    var hasLowStock: Bool {
        lowStockItemsCount > 0
    }
    
    func fetchInventory() async {
        do {
            let fetchedItems: [InventoryItem] = try await SupabaseManager.shared.client
                .from("inventory")
                .select()
                .execute()
                .value
            
            print("DECODED COUNT:", fetchedItems.count)
            
            self.items = fetchedItems
            self.filterItems()
            
        } catch {
            print("ERROR:", error)
        }
    }
    
    func filterItems() {
        var result = items
        
        // Filter by category
        if selectedVehicleFilter != "All" {
            result = result.filter {
                ($0.vehicleCategory ?? "").lowercased() == selectedVehicleFilter.lowercased()
            }
        }
        
        // Filter by search text
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
