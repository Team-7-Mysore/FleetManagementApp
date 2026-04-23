import SwiftUI

struct CategoryGridView: View {
    let lowStockItems: [InventoryItem]
    let onCategorySelected: (String) -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            ForEach(VehicleType.allCases, id: \.self) { vehicle in
                CategoryCard(
                    title: vehicle.rawValue,
                    iconName: vehicle.sfSymbol,
                    color: vehicle.color,
                    hasLowStock: lowStockItems.contains(where: { $0.vehicleCategory?.lowercased() == vehicle.rawValue.lowercased() }),
                    action: { onCategorySelected(vehicle.rawValue) }
                )
            }
        }
        .padding(.horizontal, 16)
    }
}
