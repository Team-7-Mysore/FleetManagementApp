import Foundation
import Supabase
import Combine

extension Notification.Name {
    static let tripsUpdated = Notification.Name("tripsUpdated")
    static let vehiclesUpdated = Notification.Name("vehiclesUpdated")
    static let workOrdersUpdated = Notification.Name("workOrdersUpdated")
    static let notificationsUpdated = Notification.Name("notificationsUpdated")
}

@MainActor
final class RealtimeManager {
    static let shared = RealtimeManager()
    
    private let supabase = SupabaseManager.shared.client
    private var channels: [String: RealtimeChannelV2] = [:]
    
    private init() {}
    
    func startAll() async {
        await startTripsRealtime()
        await startVehiclesRealtime()
        await startWorkOrdersRealtime()
        await startNotificationsRealtime()
    }
    
    func startTripsRealtime() async {
        guard channels["trips"] == nil else { return }
        
        let channel = supabase.realtimeV2.channel("dashboard-trips")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "trips")
        
        do {
            try await channel.subscribe()
            channels["trips"] = channel
            
            Task {
                for await _ in changes {
                    NotificationCenter.default.post(name: .tripsUpdated, object: nil)
                }
            }
        } catch {
            print("🚨 RealtimeManager: Trips subscription failed: \(error)")
        }
    }
    
    func startVehiclesRealtime() async {
        guard channels["vehicles"] == nil else { return }
        
        let channel = supabase.realtimeV2.channel("dashboard-vehicles")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "vehicles")
        
        do {
            try await channel.subscribe()
            channels["vehicles"] = channel
            
            Task {
                for await _ in changes {
                    NotificationCenter.default.post(name: .vehiclesUpdated, object: nil)
                }
            }
        } catch {
            print("🚨 RealtimeManager: Vehicles subscription failed: \(error)")
        }
    }
    
    func startWorkOrdersRealtime() async {
        guard channels["work_orders"] == nil else { return }
        
        let channel = supabase.realtimeV2.channel("dashboard-wo")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "work_orders")
        
        do {
            try await channel.subscribe()
            channels["work_orders"] = channel
            
            Task {
                for await _ in changes {
                    NotificationCenter.default.post(name: .workOrdersUpdated, object: nil)
                }
            }
        } catch {
            print("🚨 RealtimeManager: WorkOrders subscription failed: \(error)")
        }
    }
    
    func startNotificationsRealtime() async {
        guard channels["notifications"] == nil else { return }
        
        let channel = supabase.realtimeV2.channel("dashboard-notifs")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "notifications")
        
        do {
            try await channel.subscribe()
            channels["notifications"] = channel
            
            Task {
                for await action in changes {
                    // Post the in-app update so notification list views refresh
                    NotificationCenter.default.post(name: .notificationsUpdated, object: action)

                    // Fire a native iOS banner only for INSERT events addressed to this user
                    if case .insert(let insertAction) = action {
                        await fireLocalBannerIfNeeded(record: insertAction.record)
                    }
                }
            }
        } catch {
            print("🚨 RealtimeManager: Notifications subscription failed: \(error)")
        }
    }

    /// Checks the inserted notification's recipient_id against the logged-in user.
    /// If it matches, fires a UNUserNotificationCenter banner immediately.
    private func fireLocalBannerIfNeeded(record: [String: AnyJSON]) async {
        // Resolve the current user's ID from the active session
        guard let session = try? await supabase.auth.session else { return }
        let currentUserId = session.user.id.uuidString.lowercased()

        guard let recipientId = record["recipient_id"]?.stringValue?.lowercased(),
              recipientId == currentUserId else { return }

        let title   = record["title"]?.stringValue   ?? "New Notification"
        let message = record["message"]?.stringValue ?? ""
        let notifId = record["id"]?.stringValue

        NotificationManager.shared.sendInAppNotification(
            title: title,
            message: message,
            notificationId: notifId
        )
    }
}
