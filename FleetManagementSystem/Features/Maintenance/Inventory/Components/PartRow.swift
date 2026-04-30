import SwiftUI

struct PartRow: View {
    let item: InventoryItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Circular Image or Placeholder
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 50, height: 50)
                
                if let urlString = item.imageUrl, let url = URL(string: urlString) {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(.gray)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.partName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                Text(item.location ?? "No location")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.quantity)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(quantityColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(quantityColor.opacity(0.15))
                    .clipShape(Capsule())
                
                if let sku = item.sku {
                    Text(sku)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
    
    private var quantityColor: Color {
        if item.quantity == 0 { return .red }
        if item.quantity <= 10 { return .orange }
        return .green
    }
}
