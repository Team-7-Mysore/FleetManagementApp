import SwiftUI
import MapKit
import Combine
import CoreLocation

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedAddress: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    let title: String
    
    @StateObject private var viewModel = LocationPickerViewModel()
    @StateObject private var locationManager = FleetLocationManager()
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629), // India center
            span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
        )
    )
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position) {}
                    .mapControls {
                        MapCompass()
                        MapPitchToggle()
                        MapUserLocationButton()
                    }
                    .onMapCameraChange(frequency: .onEnd) { context in
                        viewModel.updateMapCenter(context.region.center)
                    }
                    .overlay(alignment: .center) {
                        VStack(spacing: 0) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(.red)
                                .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 2)
                            
                            Circle()
                                .fill(.white)
                                .frame(width: 8, height: 8)
                                .offset(y: -6)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let location = locationManager.location {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Location")
                                    .font(.caption2.weight(.semibold))
                                Text("Lat: \(String(format: "%.4f", location.coordinate.latitude))")
                                    .font(.caption2)
                                Text("Lon: \(String(format: "%.4f", location.coordinate.longitude))")
                                    .font(.caption2)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(12)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                
                VStack(spacing: 12) {
                    searchPanel
                    selectionPanel
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                locationManager.requestLocation()
                
                // Wait a bit for location to be available
                try? await Task.sleep(for: .milliseconds(500))
                
                await viewModel.loadInitialAddress(selectedAddress)
                if let coordinate = viewModel.selectedCoordinate {
                    position = .region(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                } else if let userLocation = locationManager.location {
                    position = .region(
                        MKCoordinateRegion(
                            center: userLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
                    // Update the view model with current location
                    viewModel.updateMapCenter(userLocation.coordinate)
                }
            }
            .onChange(of: locationManager.location) { oldLocation, newLocation in
                guard let newLocation = newLocation else { return }
                // Only update if we don't have a selected coordinate yet
                if viewModel.selectedCoordinate == nil {
                    position = .region(
                        MKCoordinateRegion(
                            center: newLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
                    viewModel.updateMapCenter(newLocation.coordinate)
                }
            }
            .onReceive(viewModel.$selectedCoordinate) { coordinate in
                guard let coordinate else { return }
                position = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }
    
    private var searchPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search address", text: $viewModel.query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                
                if viewModel.isSearching {
                    ProgressView()
                        .controlSize(.small)
                } else if !viewModel.query.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            
            if let error = viewModel.searchError {
                Divider()
                
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !viewModel.completions.isEmpty {
                Divider()
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.limitedCompletions) { identifiableCompletion in
                            Button {
                                Task {
                                    await viewModel.selectCompletion(identifiableCompletion.completion)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(identifiableCompletion.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    if !identifiableCompletion.subtitle.isEmpty {
                                        Text(identifiableCompletion.subtitle)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            
                            if identifiableCompletion.id != viewModel.limitedCompletions.last?.id {
                                Divider()
                                    .padding(.leading, 14)
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Selected Location")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text(viewModel.selectedAddress.isEmpty ? "Move the map or search for an address." : viewModel.selectedAddress)
                .font(.body)
                .foregroundStyle(viewModel.selectedAddress.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                selectedAddress = viewModel.selectedAddress
                selectedCoordinate = viewModel.selectedCoordinate
                dismiss()
            } label: {
                Text("Use This Location")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

@MainActor
final class LocationPickerViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = ""
    @Published private(set) var completions: [MKLocalSearchCompletion] = []
    @Published private(set) var selectedAddress = ""
    @Published private(set) var selectedCoordinate: CLLocationCoordinate2D?
    @Published private(set) var isSearching = false
    @Published private(set) var searchError: String?
    
    private let completer = MKLocalSearchCompleter()
    private let geocoder = CLGeocoder()
    private var reverseGeocodeTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    var limitedCompletions: [IdentifiableCompletion] {
        Array(completions.prefix(6)).enumerated().map { index, completion in
            IdentifiableCompletion(id: index, completion: completion)
        }
    }
    
    override init() {
        super.init()
        completer.delegate = self
        // Set broader result types to include all location types
        completer.resultTypes = [.address, .pointOfInterest, .query]
        
        // Set a default region (India-wide search area centered on Pune)
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567),
            latitudinalMeters: 500000, // 500km radius
            longitudinalMeters: 500000
        )
        
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newValue in
                self?.updateQuery(newValue)
            }
            .store(in: &cancellables)
    }
    
    func loadInitialAddress(_ address: String) async {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else { return }
        
        selectedAddress = trimmedAddress
        query = trimmedAddress
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmedAddress)
            if let location = placemarks.first?.location {
                selectedCoordinate = location.coordinate
            }
        } catch {
            // Keep the existing text if geocoding fails.
        }
    }
    
    func updateMapCenter(_ coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        
        // Update completer region to prioritize nearby results
        completer.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 100000, // 100km radius for better search results
            longitudinalMeters: 100000
        )
        
        reverseGeocodeTask?.cancel()
        reverseGeocodeTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(
                    CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                )
                
                guard let placemark = placemarks.first else { return }
                let address = formatAddress(from: placemark)
                guard !address.isEmpty else { return }
                
                selectedAddress = address
                if query.isEmpty {
                    query = address
                }
            } catch {
                // Ignore transient reverse-geocode failures while the map is moving.
            }
        }
    }
    
    func clearSearch() {
        query = ""
        completions = []
        completer.queryFragment = ""
        isSearching = false
        searchError = nil
    }
    
    func updateQuery(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Allow single character searches for better UX
        guard !trimmed.isEmpty else {
            completions = []
            completer.queryFragment = ""
            isSearching = false
            searchError = nil
            return
        }
        
        isSearching = true
        searchError = nil
        completer.queryFragment = trimmed
    }
    
    func selectCompletion(_ completion: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: completion)
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            if let item = response.mapItems.first {
                let coordinate = item.location.coordinate
                selectedCoordinate = coordinate
                
                let address = [completion.title, completion.subtitle]
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: ", ")
                
                selectedAddress = address
                query = address
                completions = []
                completer.queryFragment = ""
            }
        } catch {
            // Keep the current selection if search resolution fails.
        }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
        isSearching = false
        searchError = nil
        
        // If no results found, show a helpful message
        if completions.isEmpty && !completer.queryFragment.isEmpty {
            searchError = "No locations found. Try a different search term."
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        isSearching = false
        
        // Show error message to user
        let nsError = error as NSError
        if nsError.domain == MKError.errorDomain {
            if let mkError = MKError.Code(rawValue: UInt(nsError.code)) {
                switch mkError {
                case .placemarkNotFound:
                    searchError = "Location not found. Try a different search."
                case .serverFailure:
                    searchError = "Search service unavailable. Please try again."
                default:
                    searchError = "Search failed. Please try again."
                }
            } else {
                searchError = "Search failed. Please try again."
            }
        } else {
            searchError = "Search failed. Please check your connection."
        }
        
        // Keep old completions on transient errors to prevent flashing empty results
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        let rawParts: [String?] = [
            placemark.name,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ]
        
        var uniqueParts: [String] = []
        
        for rawPart in rawParts {
            guard let rawPart else { continue }
            let trimmed = rawPart.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !uniqueParts.contains(trimmed) {
                uniqueParts.append(trimmed)
            }
        }
        
        return uniqueParts.joined(separator: ", ")
    }
}

struct IdentifiableCompletion: Identifiable {
    let id: Int
    let completion: MKLocalSearchCompletion
    
    var title: String { completion.title }
    var subtitle: String { completion.subtitle }
}

// MARK: - Fleet Location Manager
@MainActor
class FleetLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestLocation() {
        let status = manager.authorizationStatus
        
        print("📍 Requesting location. Current status: \(status.rawValue)")
        
        if status == .notDetermined {
            print("📍 Requesting authorization...")
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("📍 Authorization granted. Starting location updates...")
            manager.startUpdatingLocation()
            // Also request a one-time location
            manager.requestLocation()
        } else {
            print("❌ Location authorization denied or restricted")
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let newLocation = locations.first {
                self.location = newLocation
                print("✅ Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            print("📍 Authorization status changed: \(manager.authorizationStatus.rawValue)")
            
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
                manager.requestLocation()
            }
        }
    }
}
