import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("❌ Notification Permission Error:", error.localizedDescription)
            }
            print("🔔 Notification Permission:", granted)
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
            if let error = error {
                print("❌ Failed to add notification:", error.localizedDescription)
            }
        }
    }
}
