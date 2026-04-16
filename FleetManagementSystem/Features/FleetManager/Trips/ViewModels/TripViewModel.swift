//
//  TripViewModel.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 16/04/26.
//

import Foundation
import Supabase

class TripViewModel {

    func createTrip(start: String, end: String, date: Date) async {
        let formatter = ISO8601DateFormatter()
        let isoDate = formatter.string(from: date)

        do {
            try await SupabaseManager.shared.client
                .from("trips")
                .insert([
                    [
                        "start_location": start,
                        "end_location": end,
                        "start_time": isoDate,
                        "status": "pending"
                    ]
                ])
                .execute()
        } catch {
            print(error)
        }
    }
}
