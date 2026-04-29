import Foundation
import Combine
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var notifications: [NotificationItem] = []
    @Published var isLoading: Bool = false
    @Published var unreadCount: Int = 0
    @Published var isPermissionGranted: Bool = false

    init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { [weak self] granted, error in
            if let error {
                print("❌ Notification Permission Error:", error.localizedDescription)
            }

            Task { @MainActor in
                self?.isPermissionGranted = granted
            }

            print("🔔 Notification Permission:", granted)
        }
    }

    func fetchNotifications() {
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            self.notifications = []
            self.isLoading = false
        }
    }

    func sendLowStockNotification(partName: String, quantity: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Low Stock Alert"
        content.body = "\(partName) is low in stock (Qty: \(quantity))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Failed to add notification:", error.localizedDescription)
            }
        }
    }
}
