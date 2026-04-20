import SwiftUI
import Combine
import Foundation
import Supabase

@MainActor
final class FleetListViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var errorMessage: String?
    
    var totalVehiclesCount: Int {
        vehicles.count
    }
    
    // For demo purposes, we'll use a hardcoded trend
    var trendText: String {
        "+4% this month"
    }

    func fetchVehicles() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("vehicle_id, vehicle_name, number_plate, brand, model, image_url, vehicle_type, fuel_type, model_year")
                .order("vehicle_name", ascending: true)
                .execute()

            vehicles = try Self.parseVehicles(from: response.data)
            isLoading = false
        } catch {
            print("❌ FetchVehicles error: \(error)")
            vehicles = []
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

private extension FleetListViewModel {
    static func parseVehicles(from data: Data) throws -> [Vehicle] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(
                domain: "FleetList",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Vehicle response was not a JSON array."]
            )
        }

        return rows.compactMap { row in
            guard let idString = stringValue(row["vehicle_id"]),
                  let id = UUID(uuidString: idString) else {
                return nil
            }

            let plate = stringValue(row["number_plate"])
            let name = stringValue(row["vehicle_name"])
            let type = stringValue(row["vehicle_type"])

            return Vehicle(
                id: id,
                name: preferredText(name, fallback: plate, defaultValue: "Unnamed Vehicle"),
                registrationNumber: preferredText(plate, fallback: nil, defaultValue: "No Plate"),
                brand: stringValue(row["brand"]),
                model: stringValue(row["model"]),
                imageURL: stringValue(row["image_url"]),
                vehicleType: preferredText(type, fallback: nil, defaultValue: "Unknown"),
                fuelType: stringValue(row["fuel_type"]),
                modelYear: stringValue(row["model_year"])
            )
        }
    }

    static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case is NSNull, nil:
            return nil
        default:
            return String(describing: value!)
        }
    }

    static func preferredText(_ primary: String?, fallback: String?, defaultValue: String) -> String {
        let primaryTrimmed = primary?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let primaryTrimmed, !primaryTrimmed.isEmpty {
            return primaryTrimmed
        }

        let fallbackTrimmed = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fallbackTrimmed, !fallbackTrimmed.isEmpty {
            return fallbackTrimmed
        }

        return defaultValue
    }
}
