import SwiftUI

struct LowStockItemCard: View {
    let item: InventoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(quantityColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(quantityColor)
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.partName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(item.vehicleCategory ?? "Other")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 8)
            
            Text("\(item.quantity)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(quantityColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(quantityColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
    
    private var quantityColor: Color {
        item.quantity == 0 ? .red : .orange
    }
}
