import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = TripViewModel()

    @State private var tripName = ""
    @State private var clientContact = ""
    @State private var origin = ""
    @State private var destination = ""
    @State private var viaPointInput = ""
    @State private var viaPoints: [String] = []
    @State private var pickupDate = Date()

    var body: some View {
        NavigationView {
            Form {

                Section(header: Text("Trip Info")) {
                    TextField("Route Name", text: $tripName)
                    TextField("Client Contact", text: $clientContact)
                }

                Section(header: Text("Route Points")) {
                    TextField("Origin", text: $origin)
                    TextField("Destination", text: $destination)

                    HStack {
                        TextField("Add Via Point", text: $viaPointInput)
                        Button("Add") {
                            if !viaPointInput.isEmpty {
                                viaPoints.append(viaPointInput)
                                viaPointInput = ""
                            }
                        }
                    }

                    ForEach(viaPoints, id: \.self) { point in
                        Text(point)
                    }
                }

                Section(header: Text("Pickup")) {
                    DatePicker("Pickup Date & Time", selection: $pickupDate)
                }

                if vm.isLoading {
                    ProgressView()
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Create Trip")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await vm.createTrip(
                                tripName: tripName,
                                clientContact: clientContact,
                                origin: origin,
                                destination: destination,
                                viaPoints: viaPoints,
                                pickupDate: pickupDate
                            )

                            if vm.errorMessage == nil {
                                dismiss()
                            }
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
