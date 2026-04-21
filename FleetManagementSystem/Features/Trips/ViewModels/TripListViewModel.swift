import SwiftUI
import Combine
import Supabase


@MainActor
final class TripListViewModel: ObservableObject {


   @Published var trips: [Trip] = []
   @Published var vehicles: [Vehicle] = []
   @Published var workOrders: [WorkOrder] = []
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

   /// Available drivers count (placeholder - extend when driver assignment is implemented)
   var availableDriverCount: Int { 12 } // TODO: Fetch from database


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

           // Fetch vehicles and work orders in parallel
           async let vehiclesTask = fetchVehicles()
           async let workOrdersTask = fetchWorkOrders()

           _ = await (vehiclesTask, workOrdersTask)

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
       } catch {
           print("❌ FetchWorkOrders error: \(error)")
       }
   }
}


