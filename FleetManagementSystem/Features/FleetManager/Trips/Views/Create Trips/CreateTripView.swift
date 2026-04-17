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
    @State private var expectedEndDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
    @State private var selectedVehicleID: UUID?
    @State private var selectedDriverID: UUID?
    @State private var activeLocationField: LocationField?

    var body: some View {
        Form {

            Section(header: Text("Trip Info")) {
                TextField("Route Name", text: $tripName)
                TextField("Client Contact", text: $clientContact)
            }

            Section(header: Text("Route Points")) {
                locationSelectionRow(
                    title: "Origin / Pickup Location",
                    value: origin
                ) {
                    activeLocationField = .origin
                }

                locationSelectionRow(
                    title: "Destination",
                    value: destination
                ) {
                    activeLocationField = .destination
                }

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

            Section(header: Text("Schedule")) {
                DatePicker("Pickup Date & Time", selection: $pickupDate)
                DatePicker("Expected End Time", selection: $expectedEndDate, in: pickupDate...)
            }

            Section(header: Text("Assignment")) {
                Button {
                    selectedVehicleID = nil
                    selectedDriverID = nil

                    Task {
                        await vm.loadAssignmentOptions(
                            pickupLocation: origin,
                            pickupDate: pickupDate,
                            expectedEndDate: expectedEndDate
                        )
                    }
                } label: {
                    if vm.isLoadingAssignments {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Checking availability...")
                        }
                    } else {
                        Text("Find Available Vehicle & Driver")
                    }
                }

                if !vm.availableVehicles.isEmpty {
                    Picker("Vehicle", selection: $selectedVehicleID) {
                        Text("Select Vehicle").tag(UUID?.none)
                        ForEach(vm.availableVehicles) { vehicle in
                            Text(vehicle.subtitle.isEmpty ? vehicle.displayName : "\(vehicle.displayName) • \(vehicle.subtitle)")
                                .tag(Optional(vehicle.id))
                        }
                    }
                }

                if !vm.availableDrivers.isEmpty {
                    Picker("Driver", selection: $selectedDriverID) {
                        Text("Select Driver").tag(UUID?.none)
                        ForEach(vm.availableDrivers) { driver in
                            Text("\(driver.name) • \(driver.subtitle)")
                                .tag(Optional(driver.id))
                        }
                    }
                }

                if !vm.isLoadingAssignments && vm.availableVehicles.isEmpty && vm.availableDrivers.isEmpty {
                    Text("Choose route and schedule, then load the available vehicle and driver options.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if vm.isLoading {
                ProgressView()
            }

            if let success = vm.successMessage {
                Text(success)
                    .foregroundColor(.green)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("Create Trip")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickupDate) { _, newValue in
            if expectedEndDate <= newValue {
                expectedEndDate = Calendar.current.date(byAdding: .hour, value: 4, to: newValue) ?? newValue
            }
            clearAssignments()
        }
        .onChange(of: expectedEndDate) { _, _ in
            clearAssignments()
        }
        .onChange(of: origin) { _, _ in
            clearAssignments()
        }
        .onChange(of: destination) { _, _ in
            clearAssignments()
        }
        .sheet(item: $activeLocationField) { field in
            switch field {
            case .origin:
                LocationPickerView(
                    selectedAddress: $origin,
                    title: "Select Pickup Location"
                )
            case .destination:
                LocationPickerView(
                    selectedAddress: $destination,
                    title: "Select Destination"
                )
            }
        }
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
                            pickupDate: pickupDate,
                            expectedEndDate: expectedEndDate,
                            vehicleID: selectedVehicleID,
                            driverID: selectedDriverID
                        )

                        if vm.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
                .disabled(vm.isLoading || vm.isLoadingAssignments)
            }
        }
    }

    private func clearAssignments() {
        selectedVehicleID = nil
        selectedDriverID = nil
        vm.resetAssignmentOptions()
    }

    private func locationSelectionRow(
        title: String,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(value.isEmpty ? "Tap to choose on map" : value)
                        .font(.body)
                        .foregroundStyle(value.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum LocationField: String, Identifiable {
    case origin
    case destination

    var id: String { rawValue }
}
