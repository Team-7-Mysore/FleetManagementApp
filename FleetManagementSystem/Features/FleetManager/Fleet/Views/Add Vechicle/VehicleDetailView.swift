//
//  VehicleDetailView.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 17/04/26.
//
import SwiftUI
import Combine
struct VehicleDetailView: View {
    let vehicleId: UUID
    @StateObject var vm = VehicleDetailViewModel()
    @State private var isEditing = false
    @State private var editableVehicle: Vehicle?
    @State private var isSaving = false

    var body: some View {
        ScrollView {
            if vm.isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if let vehicle = vm.vehicle {
                VStack(alignment: .leading, spacing: 22) {
                    vehicleImage(currentVehicle(for: vehicle))
                    vehicleHeader(currentVehicle(for: vehicle))
                    infoSection(currentVehicle(for: vehicle))
                    documentsSection
                }
                .padding()
            } else if let errorMessage = vm.errorMessage {
                ContentUnavailableView("Could Not Load Vehicle", systemImage: "exclamationmark.triangle.fill", description: Text(errorMessage))
                    .padding(.top, 60)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Vehicle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Cancel") {
                        editableVehicle = vm.vehicle
                        isEditing = false
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        Task {
                            await saveChanges()
                        }
                    } else {
                        editableVehicle = vm.vehicle
                        isEditing = true
                    }
                }
                .fontWeight(.semibold)
                .disabled(vm.vehicle == nil || isSaving)
            }
        }
        .onAppear {
            Task {
                await vm.fetchVehicle(vehicleId: vehicleId)
                editableVehicle = vm.vehicle
            }
        }
    }

    private func vehicleImage(_ vehicle: Vehicle) -> some View {
        Group {
            if let urlString = vehicle.imageURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    placeholderImage
                }
            } else {
                placeholderImage
            }
        }
        .frame(height: 210)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            Image(systemName: "car.side.fill")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
        }
    }

    private func vehicleHeader(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Registration Number", text: binding(\.registrationNumber))
                        .font(.system(size: 32, weight: .bold))
                        .textInputAutocapitalization(.characters)

                    TextField("Vehicle Name", text: binding(\.name))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(vehicle.registrationNumber)
                    .font(.system(size: 34, weight: .bold))

                Text([vehicle.vehicleType, vehicle.fuelType]
                    .compactMap { value in
                        guard let value else { return nil }
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed
                    }
                    .joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func infoSection(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BASIC INFORMATION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                if isEditing {
                    EditableInfoRow(title: "Brand", text: binding(\.brand))
                    EditableInfoRow(title: "Vehicle Type", text: binding(\.vehicleType))
                    EditableInfoRow(title: "Fuel Type", text: binding(\.fuelType))
                    EditableInfoRow(title: "Registration Number", text: binding(\.registrationNumber))
                    EditableInfoRow(title: "Model", text: binding(\.model))
                    EditableInfoRow(title: "Model Year", text: binding(\.modelYear))
                } else {
                    InfoRow(title: "Brand", value: vehicle.brand ?? "Not added")
                    InfoRow(title: "Vehicle Type", value: vehicle.vehicleType)
                    InfoRow(title: "Fuel Type", value: vehicle.fuelType ?? "Not added")
                    InfoRow(title: "Registration Number", value: vehicle.registrationNumber)
                    InfoRow(title: "Model", value: vehicle.model ?? "Not added")
                    InfoRow(title: "Model Year", value: vehicle.modelYear ?? "Not added")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DOCUMENTS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                if vm.documents.isEmpty {
                    Text("No documents uploaded yet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ForEach(vm.documents) { document in
                        if let url = URL(string: document.fileURL) {
                            Link(destination: url) {
                                DocumentRow(document: document)
                            }
                            .buttonStyle(.plain)
                        } else {
                            DocumentRow(document: document)
                        }
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func currentVehicle(for vehicle: Vehicle) -> Vehicle {
        isEditing ? (editableVehicle ?? vehicle) : vehicle
    }

    private func binding(_ keyPath: WritableKeyPath<Vehicle, String>) -> Binding<String> {
        Binding(
            get: { editableVehicle?[keyPath: keyPath] ?? vm.vehicle?[keyPath: keyPath] ?? "" },
            set: {
                if editableVehicle == nil {
                    editableVehicle = vm.vehicle
                }
                guard editableVehicle != nil else {
                    return
                }
                editableVehicle?[keyPath: keyPath] = $0
            }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<Vehicle, String?>) -> Binding<String> {
        Binding(
            get: { editableVehicle?[keyPath: keyPath] ?? vm.vehicle?[keyPath: keyPath] ?? "" },
            set: {
                if editableVehicle == nil {
                    editableVehicle = vm.vehicle
                }
                guard editableVehicle != nil else {
                    return
                }
                editableVehicle?[keyPath: keyPath] = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
            }
        )
    }

    private func saveChanges() async {
        guard let editedVehicle = editableVehicle else { return }
        isSaving = true
        vm.vehicle = editedVehicle
        let didSave = await vm.updateVehicle()
        isSaving = false
        if didSave {
            editableVehicle = vm.vehicle
            isEditing = false
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .font(.subheadline)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
    }
}

struct EditableInfoRow: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundColor(.secondary)
                .font(.subheadline)

            TextField(title, text: $text)
                .font(.body.weight(.medium))
                .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 10)
    }
}

struct DocumentRow: View {
    let document: VehicleDocument

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 30, height: 30)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(document.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            Spacer()

            Text(document.statusText)
                .font(.caption.weight(.semibold))
                .foregroundColor(statusColor)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var iconName: String {
        switch document.type.uppercased() {
        case "RC":
            return "doc.text.fill"
        case "INSURANCE":
            return "shield.lefthalf.filled"
        case "PUC":
            return "doc.badge.gearshape"
        default:
            return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch document.type.uppercased() {
        case "RC":
            return .green
        case "INSURANCE":
            return .orange
        case "PUC":
            return .red
        default:
            return .blue
        }
    }

    private var statusColor: Color {
        switch document.type.uppercased() {
        case "RC":
            return .green
        case "INSURANCE":
            return .orange
        case "PUC":
            return .red
        default:
            return .secondary
        }
    }
}
