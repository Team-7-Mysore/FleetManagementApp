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
                .value   // ✅ THIS is the correct way
            
            print("DECODED COUNT:", fetchedItems.count)
            
            self.items = fetchedItems
            self.filteredItems = fetchedItems
            
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
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { item in
                let matchName = item.partName.lowercased().contains(lowercasedSearch)
                let matchSKU = item.sku?.lowercased().contains(lowercasedSearch) ?? false
                let matchCategory = item.vehicleCategory?.lowercased().contains(lowercasedSearch) ?? false 
                return matchName || matchSKU || matchCategory
            }
        }
        
        self.filteredItems = result
    }
}
