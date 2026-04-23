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


   /// Trips that are currently active (in transit or in progress)
   var activeTrips: [Trip] {
       trips.filter {
           let s = $0.normalisedStatus
           return s == .inTransit || s == .inProgress || s == .scheduled
       }
   }


   var activeTripCount: Int { activeTrips.count }

   /// Available vehicles (not in maintenance)
   var availableVehicles: [Vehicle] {
       let maintenanceVINs = Set(workOrders.filter { $0.status == .pending || $0.status == .inProgress }.map { $0.vehicleVin })
       return vehicles.filter { !maintenanceVINs.contains($0.registrationNumber) }
   }

   var availableVehicleCount: Int { availableVehicles.count }

   /// Vehicles currently in maintenance
   var vehiclesInMaintenance: [WorkOrder] {
       workOrders.filter { $0.status == .pending || $0.status == .inProgress }
   }

   var maintenanceVehicleCount: Int { vehiclesInMaintenance.count }

   /// Available drivers (not currently assigned to active trips)
   var availableDrivers: [Driver] {
       let assignedDriverIDs = Set(activeTrips.compactMap { trip -> UUID? in
           // Need to get driver_id from trip
           // For now, return all drivers
           return nil
       })
       return drivers
   }

   var availableDriverCount: Int { drivers.count }


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
}


