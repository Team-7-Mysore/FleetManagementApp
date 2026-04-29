import SwiftUI
import Combine
import Supabase


@MainActor
final class TripListViewModel: ObservableObject {


   @Published var trips: [Trip] = []
   @Published var vehicles: [Vehicle] = []
   @Published var workOrders: [WorkOrder] = []
   @Published var drivers: [Driver] = []
   @Published var isLoading = false
   @Published var searchText = ""
   @Published var unreadNotificationCount: Int = 0
   private var cancellables = Set<AnyCancellable>()


   /// Trips that are currently ongoing (in transit or in progress)
   var activeTrips: [Trip] {
       trips.filter {
           let s = $0.normalisedStatus
           return s == .inTransit || s == .inProgress
       }
   }

   var activeTripCount: Int { activeTrips.count }

   /// Vehicles currently assigned to any upcoming or active trip
   private var busyVehicleIDs: Set<UUID> {
       let occupied = trips.filter { 
           let s = $0.normalisedStatus
           return s == .inTransit || s == .inProgress || s == .scheduled
       }
       return Set(occupied.compactMap { $0.vehicle_id })
   }

   /// Drivers currently assigned to any upcoming or active trip
   private var busyDriverIDs: Set<UUID> {
       let occupied = trips.filter { 
           let s = $0.normalisedStatus
           return s == .inTransit || s == .inProgress || s == .scheduled
       }
       return Set(occupied.compactMap { $0.driver_id })
   }

   /// Available vehicles (not in maintenance, not inactive, and not currently on a trip)
   var availableVehicles: [Vehicle] {

       let maintenanceVehicleIDs = Set(workOrders.filter { $0.status == .pending || $0.status == .inProgress }.map { $0.vehicleId })
       
       return vehicles.filter { vehicle in
           // 1. Not in maintenance status or inactive
           let s = vehicle.status?.lowercased() ?? ""
           if s == "maintenance" || s == "inactive" || s == "out_of_service" {
               return false
           }
           
           // 2. Not in active maintenance work orders
           if maintenanceVehicleIDs.contains(vehicle.id) {
               return false
           }
           
           // 3. Not currently busy on a trip
           if busyVehicleIDs.contains(vehicle.id) {
               return false
           }
           
           return true
       }

   }

   var availableVehicleCount: Int { availableVehicles.count }

   /// Vehicles currently in maintenance
   var vehiclesInMaintenance: [WorkOrder] {
       workOrders.filter { $0.status == .pending || $0.status == .inProgress }
   }

   var maintenanceVehicleCount: Int { vehiclesInMaintenance.count }

   /// Available drivers (not currently busy on a trip and license not expired)
   var availableDrivers: [Driver] {
       let now = Calendar.current.startOfDay(for: Date())
       
       return drivers.filter { driver in
           // 1. License must not be expired
           if let expiry = parseDatabaseDate(driver.licenseExpiry), expiry < now {
               return false
           }
           
           // 2. Not currently busy on a trip
           if busyDriverIDs.contains(driver.id) {
               return false
           }
           
           return true
       }
   }

   var availableDriverCount: Int { availableDrivers.count }

   private func parseDatabaseDate(_ value: String?) -> Date? {
       guard let value = value else { return nil }
       let formatter = DateFormatter()
       formatter.locale = Locale(identifier: "en_US_POSIX")
       formatter.dateFormat = "yyyy-MM-dd"
       return formatter.date(from: value)
   }


   /// Capacity percentage (ratio of active trips to total)
   var capacityPercent: Int {
       guard !trips.isEmpty else { return 0 }
       return min(Int(Double(activeTrips.count) / Double(trips.count) * 100), 100)
   }


   /// Filtered trips based on search text
   var filteredTrips: [Trip] {
       activeTrips.filter { $0.matchesSearch(searchText) }
   }


   var searchSuggestions: [String] {
       let candidates = trips.flatMap { trip in
           [
               trip.displayTripID,
               trip.tripNameText,
               trip.originText,
               trip.destinationText
           ]
       }


       let filteredCandidates = candidates.filter { candidate in
           searchText.isEmpty || candidate.localizedCaseInsensitiveContains(searchText)
       }


       var orderedSuggestions: [String] = []
       for candidate in filteredCandidates where !orderedSuggestions.contains(candidate) {
           orderedSuggestions.append(candidate)
           if orderedSuggestions.count == 6 {
               break
           }
       }


       return orderedSuggestions
   }


   func fetchTrips() async {
       isLoading = true


       do {
           let response: [Trip] = try await SupabaseManager.shared.client
               .from("trips")
               .select()
               .order("pickup_time", ascending: false)
               .execute()
               .value


           trips = response
           
           print("📊 Fetched \(trips.count) trips from Supabase")
           for trip in trips {
               print("   Trip: \(trip.tripNameText) - Status: \(trip.status ?? "nil") - Normalized: \(trip.normalisedStatus.label)")
           }
           print("   Active trips count: \(activeTrips.count)")

           // Fetch vehicles, work orders, and drivers in parallel
           async let vehiclesTask = fetchVehicles()
           async let workOrdersTask = fetchWorkOrders()
           async let driversTask = fetchDrivers()

           _ = await (vehiclesTask, workOrdersTask, driversTask)

           print("📊 Available vehicles: \(availableVehicleCount)")
           print("📊 Available drivers: \(availableDriverCount)")

           isLoading = false


       } catch {
           print("❌ FetchTrips error: \(error)")
           isLoading = false
       }
   }

   private func fetchVehicles() async {
       do {
           let response: [Vehicle] = try await SupabaseManager.shared.client
               .from("vehicles")
               .select()
               .execute()
               .value
           vehicles = response
           print("✅ Fetched \(vehicles.count) vehicles")
       } catch {
           print("❌ FetchVehicles error: \(error)")
       }
   }

   private func fetchWorkOrders() async {
       do {
           let response: [WorkOrder] = try await SupabaseManager.shared.client
               .from("work_orders")
               .select()
               .execute()
               .value
           workOrders = response
           print("✅ Fetched \(workOrders.count) work orders")
       } catch {
           print("❌ FetchWorkOrders error: \(error)")
       }
   }

   private func fetchDrivers() async {
       do {
           let response: [Driver] = try await SupabaseManager.shared.client
              .from("drivers")
              .select()
              .execute()
              .value
           drivers = response
           print("✅ Fetched \(drivers.count) drivers")
       } catch {
           print("❌ FetchDrivers error: \(error)")
       }
   }

   init() {
      setupObservers()
      Task {
          await RealtimeManager.shared.startAll()
          if let session = try? await SupabaseManager.shared.client.auth.session {
              await updateUnreadCount(userId: session.user.id)
          }
      }
   }

   private func setupObservers() {
      NotificationCenter.default.publisher(for: .tripsUpdated)
          .sink { [weak self] _ in Task { await self?.fetchTrips() } }
          .store(in: &cancellables)

      NotificationCenter.default.publisher(for: .vehiclesUpdated)
          .sink { [weak self] _ in Task { await self?.fetchTrips() } }
          .store(in: &cancellables)

      NotificationCenter.default.publisher(for: .workOrdersUpdated)
          .sink { [weak self] _ in Task { await self?.fetchTrips() } }
          .store(in: &cancellables)

      NotificationCenter.default.publisher(for: .notificationsUpdated)
          .sink { [weak self] notification in
              Task {
                  guard let self = self else { return }
                  if let action = notification.object as? AnyAction,
                     let session = try? await SupabaseManager.shared.client.auth.session {
                      
                      let userId = session.user.id
                      let recipientId: String? = {
                          switch action {
                          case .insert(let act): return act.record["recipient_id"]?.stringValue
                          case .update(let act): return act.record["recipient_id"]?.stringValue
                          case .delete(let act): return act.oldRecord["recipient_id"]?.stringValue
                          default: return nil
                          }
                      }()
                      
                      if recipientId == userId.uuidString {
                          await self.updateUnreadCount(userId: userId)
                      }
                  }
              }
          }
          .store(in: &cancellables)
   }

   private func updateUnreadCount(userId: UUID) async {
      do {
         let response = try await SupabaseManager.shared.client
            .from("notifications")
            .select("id", head: true, count: .exact)
            .eq("recipient_id", value: userId)
            .eq("is_read", value: false)
            .execute()
         
         let count = response.count ?? 0
         await MainActor.run {
            self.unreadNotificationCount = count
         }
      } catch {
         print("🚨 Failed to update unread count: \(error)")
      }
   }
}
