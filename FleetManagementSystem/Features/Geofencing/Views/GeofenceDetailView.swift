//
//  GeofenceDetailView.swift
//  FleetManagementSystem
//
//  Created by Kiro on 2025
//

import SwiftUI
import MapKit

struct GeofenceDetailView: View {
    let geofence: Geofence
    var profile: UserProfile?

    @StateObject private var viewModel = GeofenceViewModel()
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var assignedVehicles: [Vehicle] = []
    @State private var selectedDateRange: DateRange = .last7Days
    @State private var showingEditSheet: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var showingCustomDatePicker: Bool = false
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var exportURL: URL? = nil
    @State private var showingShareSheet: Bool = false

    // MARK: - Computed

    private var isFleetManager: Bool {
        profile?.role == .fleetManager
    }

    private var mapCameraPosition: MapCameraPosition {
        let coord = CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude)
        let span = MKCoordinateSpan(
            latitudeDelta: (geofence.radius / 111_000) * 4,
            longitudeDelta: (geofence.radius / 111_000) * 4
        )
        return .region(MKCoordinateRegion(center: coord, span: span))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                infoSection
                mapSection
                assignedVehiclesSection
                eventHistorySection
            }
            .padding(.horizontal, AppTheme.paddingMedium)
            .padding(.vertical, AppTheme.paddingMedium)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(geofence.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingEditSheet) {
            GeofenceCreateEditView(profile: profile, viewModel: viewModel, mode: .edit, existingGeofence: geofence)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .alert("Delete Geofence", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await handleDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(geofence.name)\"? This action cannot be undone.")
        }
        .task {
            assignedVehicles = await viewModel.loadAssignedVehicles(for: geofence.id)
            await viewModel.loadEvents(for: geofence.id, dateRange: selectedDateRange)
        }
        .onChange(of: selectedDateRange) { _, newRange in
            Task {
                await viewModel.loadEvents(for: geofence.id, dateRange: newRange)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isFleetManager {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    handleExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(AppTheme.statusDanger)
                }
            }
        } else {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    handleExport()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Geofence Info")

            VStack(spacing: 0) {
                infoRow(label: "Name", value: geofence.name)
                Divider().padding(.leading, AppTheme.paddingMedium)
                infoRow(label: "Type", value: geofence.type.displayName, icon: geofence.type.icon, iconColor: geofence.type.color)
                Divider().padding(.leading, AppTheme.paddingMedium)
                infoRow(label: "Latitude", value: String(format: "%.6f°", geofence.latitude))
                Divider().padding(.leading, AppTheme.paddingMedium)
                infoRow(label: "Longitude", value: String(format: "%.6f°", geofence.longitude))
                Divider().padding(.leading, AppTheme.paddingMedium)
                infoRow(label: "Radius", value: formattedRadius(geofence.radius))
                Divider().padding(.leading, AppTheme.paddingMedium)
                infoRow(label: "Created", value: formattedDate(geofence.created_at))
            }
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
        }
    }

    private func infoRow(label: String, value: String, icon: String? = nil, iconColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(iconColor)
                    .padding(.trailing, 4)
            }
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, AppTheme.paddingMedium)
        .padding(.vertical, 12)
    }

    // MARK: - Map Section

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Location")

            Map(initialPosition: mapCameraPosition) {
                Annotation(geofence.name, coordinate: CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude)) {
                    Image(systemName: geofence.type.icon)
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Circle().fill(geofence.type.color))
                }
                MapCircle(
                    center: CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude),
                    radius: geofence.radius
                )
                .foregroundStyle(geofence.type.color.opacity(0.15))
                .stroke(geofence.type.color.opacity(0.6), lineWidth: 2)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
            .disabled(true)
        }
    }

    // MARK: - Assigned Vehicles Section

    private var assignedVehiclesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Assigned Vehicles (\(assignedVehicles.count))")

            if assignedVehicles.isEmpty {
                emptyCard(icon: "car.fill", message: "No vehicles assigned to this geofence")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(assignedVehicles.enumerated()), id: \.element.id) { index, vehicle in
                        vehicleRow(vehicle)
                        if index < assignedVehicles.count - 1 {
                            Divider().padding(.leading, AppTheme.paddingMedium)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
            }
        }
    }

    private func vehicleRow(_ vehicle: Vehicle) -> some View {
        HStack(spacing: 12) {
            Image(systemName: vehicle.imageSystemName)
                .font(.title3)
                .foregroundColor(AppTheme.primaryGreen)
                .frame(width: 36, height: 36)
                .background(Circle().fill(AppTheme.lightGreen))

            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.name)
                    .font(.subheadline.weight(.medium))
                Text(vehicle.registrationNumber)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.paddingMedium)
        .padding(.vertical, 12)
    }

    // MARK: - Event History Section

    private var eventHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Event History")

            dateRangePicker

            if showingCustomDatePicker {
                customDateRangeView
            }

            if viewModel.isLoading {
                loadingCard
            } else if viewModel.events.isEmpty {
                emptyCard(icon: "clock.fill", message: "No events in the selected date range")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.events.enumerated()), id: \.element.id) { index, event in
                        eventRow(event)
                        if index < viewModel.events.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
            }
        }
    }

    private var dateRangePicker: some View {
        Picker("Date Range", selection: dateRangeBinding) {
            Text("7 Days").tag(0)
            Text("30 Days").tag(1)
            Text("90 Days").tag(2)
            Text("Custom").tag(3)
        }
        .pickerStyle(.segmented)
    }

    private var dateRangeBinding: Binding<Int> {
        Binding(
            get: {
                switch selectedDateRange {
                case .last7Days: return 0
                case .last30Days: return 1
                case .last90Days: return 2
                case .custom: return 3
                }
            },
            set: { newValue in
                switch newValue {
                case 0:
                    selectedDateRange = .last7Days
                    showingCustomDatePicker = false
                case 1:
                    selectedDateRange = .last30Days
                    showingCustomDatePicker = false
                case 2:
                    selectedDateRange = .last90Days
                    showingCustomDatePicker = false
                case 3:
                    showingCustomDatePicker = true
                    selectedDateRange = .custom(start: customStartDate, end: customEndDate)
                default:
                    break
                }
            }
        )
    }

    private var customDateRangeView: some View {
        VStack(spacing: 0) {
            DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                .padding(.horizontal, AppTheme.paddingMedium)
                .padding(.vertical, 10)
                .onChange(of: customStartDate) { _, _ in
                    selectedDateRange = .custom(start: customStartDate, end: customEndDate)
                }

            Divider().padding(.leading, AppTheme.paddingMedium)

            DatePicker("End Date", selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
                .padding(.horizontal, AppTheme.paddingMedium)
                .padding(.vertical, 10)
                .onChange(of: customEndDate) { _, _ in
                    selectedDateRange = .custom(start: customStartDate, end: customEndDate)
                }
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    private func eventRow(_ event: GeofenceEvent) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(event.event_type == .entry ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: event.event_type == .entry ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundColor(event.event_type == .entry ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.event_type == .entry ? "Entry" : "Exit")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(event.event_type == .entry ? .green : .red)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(abbreviatedVehicleId(event.vehicle_id))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Text(formattedTimestamp(event.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let dwell = event.formattedDwellTime {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Dwell: \(dwell)")
                            .font(.caption)
                            .foregroundColor(AppTheme.primaryGreen)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.paddingMedium)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func emptyCard(icon: String, message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Loading events…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.paddingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }

    private func formattedRadius(_ radius: Double) -> String {
        if radius >= 1000 {
            return String(format: "%.1f km", radius / 1000)
        } else {
            return String(format: "%.0f m", radius)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func abbreviatedVehicleId(_ id: UUID) -> String {
        let str = id.uuidString
        return String(str.prefix(8)).uppercased()
    }

    // MARK: - Actions

    private func handleExport() {
        guard let url = viewModel.exportEvents(viewModel.events) else { return }
        exportURL = url
        showingShareSheet = true
    }

    private func handleDelete() async {
        await viewModel.deleteGeofence(geofence)
        if viewModel.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - UIActivityViewController Wrapper

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GeofenceDetailView(geofence: Geofence(
            id: UUID(),
            name: "Main Depot",
            latitude: 12.9716,
            longitude: 77.5946,
            radius: 500,
            type: .depot,
            created_at: Date(),
            updated_at: Date()
        ))
    }
}
