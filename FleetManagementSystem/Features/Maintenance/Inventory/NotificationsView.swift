import SwiftUI

struct AppNotification: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let timestamp: Date
}

struct NotificationsView: View {
    // Current dummy implementation as no backend specified for notifications
    @State private var notifications: [AppNotification] = []
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            if notifications.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No notifications")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("We'll notify you when components need attention or stock levels change.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List(notifications) { notification in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(notification.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(notification.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        Text(notification.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Notifications")
    }
}
