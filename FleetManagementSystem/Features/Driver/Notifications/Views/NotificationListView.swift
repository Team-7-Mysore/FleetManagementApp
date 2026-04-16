import SwiftUI

// MARK: - Notification List View
struct NotificationListView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss

    @State private var notifications: [AppNotification] = []
    private let service = NotificationService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if notifications.isEmpty {
                        EmptyStateView(
                            icon: "bell.slash",
                            title: "No Notifications",
                            message: "You're all caught up!"
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(notifications) { notification in
                            notificationRow(notification)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .tint(AppTheme.primaryGreen)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Read All") {
                        service.markAllAsRead(forUser: user.id)
                        loadData()
                    }
                    .font(.caption)
                    .tint(AppTheme.primaryGreen)
                }
            }
            .onAppear { loadData() }
        }
    }

    private func loadData() {
        notifications = service.fetchNotifications(forUser: user.id)
    }

    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(spacing: 14) {
            Image(systemName: notification.type.systemImage)
                .font(.body)
                .foregroundStyle(notification.isRead ? .secondary : AppTheme.primaryGreen)
                .frame(width: 40, height: 40)
                .background(
                    (notification.isRead ? Color(.systemGray5) : AppTheme.lightGreen)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                    .foregroundStyle(.primary)
                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(notification.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(AppTheme.primaryGreen)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(14)
        .cardStyle()
        .onTapGesture {
            service.markAsRead(notificationId: notification.id)
            loadData()
        }
    }
}
