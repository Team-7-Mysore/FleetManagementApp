import Foundation
import Combine
import Supabase

@MainActor
final class FleetManagerDashboardViewModel: ObservableObject {
    @Published private(set) var vehicles: [Vehicle] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func loadVehicles() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("vehicle_id, vehicle_name, number_plate, brand, model, image_url, vehicle_type, fuel_type, model_year")
                .order("vehicle_name", ascending: true)
                .execute()

            vehicles = try FleetManagerDashboardViewModel.parseVehicles(from: response.data)
        } catch {
            errorMessage = "Please try again."
        }

        isLoading = false
    }

    private static func parseVehicles(from data: Data) throws -> [Vehicle] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: "FleetManagerDashboard", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response format."])
        }

        return rows.compactMap { row in
            guard let idString = row["vehicle_id"] as? String,
                  let id = UUID(uuidString: idString) else { return nil }

            let plate = row["number_plate"] as? String
            let name  = row["vehicle_name"] as? String
            let type  = row["vehicle_type"] as? String

            return Vehicle(
                id: id,
                name: name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? name! : (plate ?? "Unnamed Vehicle"),
                registrationNumber: plate ?? "No Plate",
                brand: row["brand"] as? String,
                model: row["model"] as? String,
                imageURL: row["image_url"] as? String,
                vehicleType: type ?? "Unknown",
                fuelType: row["fuel_type"] as? String,
                modelYear: (row["model_year"] as? Int).map(String.init)
                         ?? row["model_year"] as? String
            )
        }
    }
}
