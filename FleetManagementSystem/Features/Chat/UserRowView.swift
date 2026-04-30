import SwiftUI

struct UserRowView: View {
    let user: AppUser
    let accent = AppTheme.primaryGreen
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.1))
                    .frame(width: 45, height: 45)
                
                Text(user.name.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundColor(accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.body)
                    .fontWeight(.semibold)
                
                Text(user.role.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(user.email)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 10)
    }
}

#Preview {
    UserRowView(user: AppUser(id: UUID(), name: "John Doe", email: "john@example.com", role: "fleet_manager", avatarUrl: nil))
}
