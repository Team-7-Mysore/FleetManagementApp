import SwiftUI
import Combine
import Supabase

struct TripInsert: Encodable {
    let trip_name: String
    let client_contact: String
    let origin: String
    let destination: String
    let via_points: [String]
    let pickup_time: String
    let status: String
}

@MainActor
final class TripViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?

    func createTrip(
        tripName: String,
        clientContact: String,
        origin: String,
        destination: String,
        viaPoints: [String],
        pickupDate: Date
    ) async {

        if tripName.isEmpty || origin.isEmpty || destination.isEmpty {
            errorMessage = "Required fields missing"
            return
        }

        isLoading = true
        errorMessage = nil

        let formatter = ISO8601DateFormatter()
        let isoDate = formatter.string(from: pickupDate)

        let trip = TripInsert(
            trip_name: tripName,
            client_contact: clientContact,
            origin: origin,
            destination: destination,
            via_points: viaPoints,
            pickup_time: isoDate,
            status: "pending"
        )

        do {
            try await SupabaseManager.shared.client
                .from("trips")
                .insert(trip)
                .execute()

            isLoading = false

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}
