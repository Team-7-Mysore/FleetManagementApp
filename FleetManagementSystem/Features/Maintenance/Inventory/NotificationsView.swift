import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var notificationManager: NotificationManager

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if notificationManager.isLoading {
                ProgressView("Loading Notifications...")
            } else if notificationManager.notifications.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("No notifications")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            } else {
                List {
                    ForEach(notificationManager.notifications) { notification in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(notification.title)
                                .font(.headline)

                            Text(notification.message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .task {
            notificationManager.fetchNotifications()
        }
        .refreshable {
            notificationManager.fetchNotifications()
        }
    }
}
