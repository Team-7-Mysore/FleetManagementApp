import SwiftUI

struct NotificationExampleView: View {
    @EnvironmentObject var notificationManager: NotificationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.title2.bold())

            Text("Unread count: \(notificationManager.unreadCount)")
                .font(.subheadline)

            Button("Request Permission") {
                notificationManager.requestPermission()
            }
        }
        .padding(16)
    }
}

#Preview {
    NotificationExampleView()
        .environmentObject(NotificationManager.shared)
}
