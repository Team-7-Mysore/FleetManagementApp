import Foundation

// MARK: - Notification Service
final class NotificationService {
    static let shared = NotificationService()
    private let store = MockDataStore.shared

    private init() {}

    func fetchNotifications(forUser userId: UUID) -> [AppNotification] {
        store.notifications
            .filter { $0.userId == userId }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func unreadCount(forUser userId: UUID) -> Int {
        store.notifications.filter { $0.userId == userId && !$0.isRead }.count
    }

    func markAsRead(notificationId: UUID) {
        guard let idx = store.notifications.firstIndex(where: { $0.id == notificationId }) else { return }
        store.notifications[idx].isRead = true
    }

    func markAllAsRead(forUser userId: UUID) {
        for idx in store.notifications.indices where store.notifications[idx].userId == userId {
            store.notifications[idx].isRead = true
        }
    }
}
