import SwiftUI

struct FormCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 24)
            .padding(.top, 10)
            
            VStack(spacing: 0) {
                content
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .padding(.horizontal)
        }
    }
}
