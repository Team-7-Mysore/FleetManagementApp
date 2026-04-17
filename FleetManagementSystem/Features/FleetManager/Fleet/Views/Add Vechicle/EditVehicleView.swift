//
//  EditVehicleView.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 17/04/26.
//
import SwiftUI

struct EditVehicleView: View {
    @ObservedObject var vm: VehicleDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        if let vehicle = vm.vehicle {
            Form {
                TextField("Brand", text: binding(\.brand))
                TextField("Model", text: binding(\.model))
                TextField("Fuel Type", text: binding(\.fuelType))
                TextField("Vehicle Type", text: binding(\.vehicleType))
                TextField("Model Year", text: binding(\.modelYear))
                
                Button("Save Changes") {
                    Task {
                        await vm.updateVehicle()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // For optional String?
    private func binding(_ keyPath: WritableKeyPath<Vehicle, String?>) -> Binding<String> {
        Binding(
            get: { vm.vehicle?[keyPath: keyPath] ?? "" },
            set: { vm.vehicle?[keyPath: keyPath] = $0 }
        )
    }

    // For non-optional String
    private func binding(_ keyPath: WritableKeyPath<Vehicle, String>) -> Binding<String> {
        Binding(
            get: { vm.vehicle?[keyPath: keyPath] ?? "" },
            set: { vm.vehicle?[keyPath: keyPath] = $0 }
        )
    }
}
