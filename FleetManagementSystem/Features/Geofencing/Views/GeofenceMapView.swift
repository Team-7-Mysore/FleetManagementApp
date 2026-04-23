//
//  GeofenceMapView.swift
//  FleetManagementSystem
//
//  Created by Kiro on 2025
//

import SwiftUI
import MapKit

// MARK: - GeofenceMapView

struct GeofenceMapView: View {
    @StateObject private var viewModel = GeofenceViewModel()
    var profile: UserProfile?

    // Map camera position
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )

    // Task 10.2 – tap-to-create state
    @State private var isCreatingGeofence: Bool = false
    @State private var pendingCoordinate: CLLocationCoordinate2D? = nil
    @State private var showingCreateSheet: Bool = false

    // Task 10.3 – selection state
    @State private var selectedGeofence: Geofence? = nil
    @State private var navigateToDetail: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                mapView

                // Tap-to-create overlay hint
                if isCreatingGeofence {
                    creatingHintBanner
                }
            }
            .navigationTitle("Geofence Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            // Task 10.2 – present create sheet with pre-filled coordinates
            .sheet(isPresented: $showingCreateSheet, onDismiss: {
                pendingCoordinate = nil
                isCreatingGeofence = false
            }) {
                if let coord = pendingCoordinate {
                    GeofenceCreateEditViewWithCoord(
                        profile: profile,
                        viewModel: viewModel,
                        latitude: coord.latitude,
                        longitude: coord.longitude
                    )
                }
            }
            // Task 10.3 – navigate to detail
            .navigationDestination(isPresented: $navigateToDetail) {
                if let geofence = selectedGeofence {
                    GeofenceDetailView(geofence: geofence, profile: profile)
                }
            }
            .task {
                if viewModel.geofences.isEmpty {
                    await viewModel.loadGeofences()
                }
            }
        }
    }

    // MARK: - Map

    private var mapView: some View {
        Map(position: $cameraPosition) {
            // Task 10.1 – geofence circle overlays
            ForEach(viewModel.geofences) { geofence in
                let center = CLLocationCoordinate2D(
                    latitude: geofence.latitude,
                    longitude: geofence.longitude
                )

                // Filled circle overlay
                MapCircle(center: center, radius: geofence.radius)
                    .foregroundStyle(geofence.type.color.opacity(0.15))
                    .stroke(geofence.type.color, lineWidth: 2)

                // Task 10.3 – annotation for tap / callout
                Annotation(geofence.name, coordinate: center) {
                    GeofenceAnnotationView(
                        geofence: geofence,
                        isSelected: selectedGeofence?.id == geofence.id,
                        onTap: {
                            if selectedGeofence?.id == geofence.id {
                                // Second tap → navigate to detail
                                navigateToDetail = true
                            } else {
                                selectedGeofence = geofence
                            }
                        }
                    )
                }
            }

            // Task 10.2 – temporary pending circle while creating
            if let coord = pendingCoordinate {
                MapCircle(center: coord, radius: 200)
                    .foregroundStyle(Color.orange.opacity(0.2))
                    .stroke(Color.orange, lineWidth: 2)

                Annotation("New Geofence", coordinate: coord) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .background(Circle().fill(.white).padding(-2))
                }
            }

            // Task 10.1 – vehicle markers (from vehicleStatuses)
            ForEach(Array(viewModel.vehicleStatuses.keys), id: \.self) { vehicleId in
                if let statuses = viewModel.vehicleStatuses[vehicleId],
                   let status = statuses.first {
                    // Show a marker at the geofence center as a proxy for vehicle location
                    if let geofence = viewModel.geofences.first(where: { $0.id == status.geofence_id }) {
                        Marker(
                            "Vehicle",
                            systemImage: "car.fill",
                            coordinate: CLLocationCoordinate2D(
                                latitude: geofence.latitude,
                                longitude: geofence.longitude
                            )
                        )
                        .tint(AppTheme.primaryGreen)
                    }
                }
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .onTapGesture { _ in
            // Dismiss callout when tapping empty map area
            if !isCreatingGeofence {
                selectedGeofence = nil
            }
        }
        // Task 10.2 – tap gesture to place new geofence
        .overlay(
            Group {
                if isCreatingGeofence {
                    MapTapOverlay { coordinate in
                        pendingCoordinate = coordinate
                        showingCreateSheet = true
                    }
                }
            }
        )
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Creating Hint Banner

    private var creatingHintBanner: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .foregroundColor(.white)
                Text("Tap on the map to place a geofence")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    isCreatingGeofence = false
                    pendingCoordinate = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(Color.orange)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if isFleetManager {
                Button {
                    isCreatingGeofence.toggle()
                    if !isCreatingGeofence {
                        pendingCoordinate = nil
                    }
                } label: {
                    Image(systemName: isCreatingGeofence ? "xmark" : "plus")
                        .font(.body.weight(.semibold))
                }
            }
        }
    }

    // MARK: - Helpers

    private var isFleetManager: Bool {
        profile?.role == .fleetManager
    }
}

// MARK: - Geofence Annotation View

private struct GeofenceAnnotationView: View {
    let geofence: Geofence
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if isSelected {
                // Callout bubble
                VStack(alignment: .leading, spacing: 4) {
                    Text(geofence.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: geofence.type.icon)
                            .font(.caption)
                            .foregroundColor(geofence.type.color)
                        Text(geofence.type.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(String(format: "%.0f m radius", geofence.radius))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Tap again for details")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(AppTheme.primaryGreen)
                        .padding(.top, 2)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
                )
                .padding(.bottom, 4)
            }

            // Pin icon
            Button(action: onTap) {
                Image(systemName: geofence.type.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(geofence.type.color)
                            .shadow(color: geofence.type.color.opacity(0.4), radius: 4, x: 0, y: 2)
                    )
            }
        }
    }
}

// MARK: - Map Tap Overlay

/// Transparent overlay that captures taps and converts them to map coordinates.
private struct MapTapOverlay: UIViewRepresentable {
    let onTap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        let onTap: (CLLocationCoordinate2D) -> Void

        init(onTap: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let point = gesture.location(in: view)
            // Convert screen point to coordinate using the view bounds as a rough approximation.
            // The Map view fills the screen, so we map the tap point to a coordinate
            // by walking up the view hierarchy to find the MKMapView.
            if let mapView = findMapView(in: view) {
                let coord = mapView.convert(gesture.location(in: mapView), toCoordinateFrom: mapView)
                onTap(coord)
            } else {
                // Fallback: use a default coordinate offset based on tap position
                let normalizedX = point.x / view.bounds.width - 0.5
                let normalizedY = point.y / view.bounds.height - 0.5
                // Default center (San Francisco) as fallback
                let coord = CLLocationCoordinate2D(
                    latitude: 37.7749 - normalizedY * 0.1,
                    longitude: -122.4194 + normalizedX * 0.1
                )
                onTap(coord)
            }
        }

        private func findMapView(in view: UIView) -> MKMapView? {
            // Walk up the view hierarchy
            var current: UIView? = view
            while let v = current {
                if let mapView = v as? MKMapView { return mapView }
                current = v.superview
            }
            // Walk down from window
            if let window = view.window {
                return findMapViewDown(in: window)
            }
            return nil
        }

        private func findMapViewDown(in view: UIView) -> MKMapView? {
            if let mapView = view as? MKMapView { return mapView }
            for subview in view.subviews {
                if let found = findMapViewDown(in: subview) { return found }
            }
            return nil
        }
    }
}

// MARK: - GeofenceCreateEditView with pre-filled coordinates

/// Wrapper that pre-fills latitude/longitude when creating from map tap.
private struct GeofenceCreateEditViewWithCoord: View {
    @Environment(\.dismiss) private var dismiss
    var profile: UserProfile?
    @ObservedObject var viewModel: GeofenceViewModel

    let latitude: Double
    let longitude: Double

    var body: some View {
        GeofenceCreateEditView(
            profile: profile,
            viewModel: viewModel,
            mode: .create,
            existingGeofence: nil,
            prefilledLatitude: latitude,
            prefilledLongitude: longitude
        )
    }
}

// MARK: - Preview

#Preview {
    GeofenceMapView()
}
