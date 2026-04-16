//
//  CreateTripView.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 16/04/26.
//

import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) var dismiss

    @State private var startLocation = ""
    @State private var endLocation = ""
    @State private var selectedDate = Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Trip Details")) {
                    TextField("Start Location", text: $startLocation)
                    TextField("End Location", text: $endLocation)
                    DatePicker("Date & Time", selection: $selectedDate)
                }
            }
            .navigationTitle("Create Trip")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await TripViewModel().createTrip(
                                start: startLocation,
                                end: endLocation,
                                date: selectedDate
                            )
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
