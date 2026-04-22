import SwiftUI

// MARK: - Notification List View
struct NotificationListView: View {
    let user: User
    @Environment(\.dismiss) private var dismiss

    @State private var notifications: [AppNotification] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()
                
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
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .onAppear { loadData() }
        }
    }

    private func loadData() {
        // Notifications fetched from Supabase or local store when backend is ready.
        // For now returns empty list — extend with a NotificationService once the
        // notifications table is added to the DB schema.
        notifications = []
    }

    private func notificationRow(_ notification: AppNotification) -> some View {
        HStack(spacing: 14) {
            Image(systemName: notification.type.systemImage)
                .font(.body)
                .foregroundStyle(notification.isRead ? .secondary : AppTheme.primaryGreen)
                .frame(width: 40, height: 40)
                .background(
                    notification.isRead ? Color(.systemGray5) : AppTheme.lightGreen
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
    }
}
