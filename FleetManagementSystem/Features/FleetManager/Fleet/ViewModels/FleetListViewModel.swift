import SwiftUI
import Combine
import Foundation
import Supabase

@MainActor
final class FleetListViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var isLoading = false
    @Published var searchText = ""
    
    var totalVehiclesCount: Int {
        vehicles.count
    }
    
    // For demo purposes, we'll use a hardcoded trend
    var trendText: String {
        "+4% this month"
    }

    func fetchVehicles() async {
        isLoading = true
        // In a real app, we would fetch from Supabase
        // For now, let's try to fetch if we have a table, otherwise use mock data if it fails
        do {
            let response: [Vehicle] = try await SupabaseManager.shared.client
                .from("vehicles")
                .select()
                .execute()
                .value
            
            vehicles = response
            isLoading = false
        } catch {
            print("❌ FetchVehicles error: \(error)")
            vehicles = []
            isLoading = false
        }
    }
}
