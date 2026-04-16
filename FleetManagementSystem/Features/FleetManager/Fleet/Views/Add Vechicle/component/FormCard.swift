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
        VStack(alignment: .leading, spacing: 16) {
            
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color.primaryBrown)
                
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .padding(.horizontal)
    }
}
