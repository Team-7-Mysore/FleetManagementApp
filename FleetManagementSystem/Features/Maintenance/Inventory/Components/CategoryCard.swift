import SwiftUI

struct CategoryCard: View {
    let title: String
    let iconName: String
    let color: Color
    let hasLowStock: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: iconName)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(color)
                        .frame(width: 64, height: 64)
                        .background(color.opacity(0.1))
                        .cornerRadius(16)
                }
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .padding(.vertical, 20)
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        CategoryCard(title: "Truck", iconName: "truck.box", color: .blue, hasLowStock: true, action: {})
        CategoryCard(title: "Bus", iconName: "bus", color: .green, hasLowStock: false, action: {})
        CategoryCard(title: "Car", iconName: "car", color: .orange, hasLowStock: false, action: {})
        CategoryCard(title: "Bike", iconName: "bicycle", color: .purple, hasLowStock: true, action: {})
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
