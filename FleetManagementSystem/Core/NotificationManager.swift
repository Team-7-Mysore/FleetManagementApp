import Foundation
import Combine
import UserNotifications

/// Manages all local (iOS-native) notification concerns.
/// No APNs, no external services — purely UNUserNotificationCenter.
///
/// How in-app push works:
///   1. Supabase Realtime fires when a row is INSERTed into `notifications`.
///   2. RealtimeManager checks the recipient_id matches the logged-in user.
///   3. RealtimeManager calls NotificationManager.shared.sendInAppNotification().
///   4. UNUserNotificationCenter delivers a banner — even while the app is in the foreground
///      because this class sets itself as the UNUserNotificationCenterDelegate.
@MainActor
final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    // MARK: - Published Properties

    @Published var notifications: [NotificationItem] = []
    @Published var isLoading: Bool = false
    @Published var unreadCount: Int = 0
    @Published var isPermissionGranted: Bool = false

    // MARK: - Initialization

    private override init() {
        super.init()
        // Must be set before the app finishes launching so foreground banners work
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { [weak self] granted, error in
            if let error {
                print("❌ Notification permission error:", error.localizedDescription)
            }

            Task { @MainActor in
                self?.isPermissionGranted = granted
            }

            print("🔔 Notification permission granted:", granted)
        }
    }

    // MARK: - Fetch Notifications

    func fetchNotifications() {
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            self.notifications = []
            self.isLoading = false
        }
    }

    // MARK: - In-App Push (triggered by Supabase Realtime INSERT on notifications table)

    /// Call this whenever a new notification row is inserted for the current user.
    /// Delivers a native iOS banner regardless of whether the app is foreground or background.
    func sendInAppNotification(title: String, message: String, notificationId: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        // Use the Supabase notification ID as the identifier so duplicate inserts
        // don't produce duplicate banners (UNUserNotificationCenter deduplicates by id)
        let identifier = notificationId ?? UUID().uuidString

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // nil = deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Failed to deliver in-app notification:", error.localizedDescription)
            } else {
                print("✅ In-app notification delivered: \(title)")
            }
        }
    }

    // MARK: - Low Stock Local Notification

    func sendLowStockNotification(partName: String, quantity: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Low Stock Alert"
        content.body = "\(partName) is low in stock (Qty: \(quantity))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "low_stock_\(partName)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("❌ Failed to schedule low stock notification:", error.localizedDescription)
            } else {
                print("✅ Low stock notification sent: \(partName)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Show banners even when the app is in the foreground.
    /// Without this, iOS silently drops local notifications while the app is active.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle tap on a notification banner (brings app to foreground if backgrounded).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // You can handle notification tap actions here
        // For example, navigate to a specific screen based on notification data

        let userInfo = response.notification.request.content.userInfo
        print("📱 User tapped notification:", userInfo)

        completionHandler()
    }
}
