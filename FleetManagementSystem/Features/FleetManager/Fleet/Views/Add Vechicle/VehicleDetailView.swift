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

    var body: some View {
        ScrollView {
            if vm.isLoading {
                ProgressView()
                    .padding(.top, 60)
            } else if let vehicle = vm.vehicle {
                VStack(alignment: .leading, spacing: 22) {
                    vehicleImage(vehicle)
                    vehicleHeader(vehicle)
                    infoSection(vehicle)
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
        .alert(
            "Update Failed",
            isPresented: Binding(
                get: { vm.errorMessage != nil && vm.vehicle != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
                .fontWeight(.semibold)
                .disabled(vm.vehicle == nil)
            }
        }
        .onAppear {
            Task {
                await vm.fetchVehicle(vehicleId: vehicleId)
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                EditVehicleView(vm: vm)
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
                    placeholderImage(vehicle.vehicleType)
                }
            } else {
                placeholderImage(vehicle.vehicleType)
            }
        }
        .frame(height: 210)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func placeholderImage(_ vehicleType: String?) -> some View {
        VehicleFallbackArtwork(vehicleType: vehicleType)
    }

    private func vehicleHeader(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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

    private func infoSection(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BASIC INFORMATION")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                InfoRow(title: "Brand", value: vehicle.brand ?? "Not added")
                InfoRow(title: "Vehicle Type", value: vehicle.vehicleType)
                InfoRow(title: "Fuel Type", value: vehicle.fuelType ?? "Not added")
                InfoRow(title: "Registration Number", value: vehicle.registrationNumber)
                InfoRow(title: "Model", value: vehicle.model ?? "Not added")
                InfoRow(title: "Model Year", value: vehicle.modelYear ?? "Not added")
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
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                if let documentsErrorMessage = vm.documentsErrorMessage {
                    Text(documentsErrorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else if vm.documents.isEmpty {
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

struct DocumentRow: View {
    let document: VehicleDocument

    var body: some View {
        HStack(spacing: 12) {
            if isImageDocument, let url = URL(string: document.fileURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    iconBadge
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                iconBadge
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(isImageDocument ? "Image Document" : "Open Document")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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

    private var isImageDocument: Bool {
        guard let url = URL(string: document.fileURL) else { return false }
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "webp", "heic"].contains(ext)
    }

    private var iconBadge: some View {
        Image(systemName: iconName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(iconColor)
            .frame(width: 30, height: 30)
            .background(iconColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
