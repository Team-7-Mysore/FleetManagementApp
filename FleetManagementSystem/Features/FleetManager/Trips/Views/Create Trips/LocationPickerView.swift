import SwiftUI
import MapKit
import Combine
import CoreLocation

// MARK: - IdentifiableCompletion

struct IdentifiableCompletion: Identifiable {
    let id: Int
    let completion: MKLocalSearchCompletion
    var title: String { completion.title }
    var subtitle: String { completion.subtitle }
}

// MARK: - LocationPickerView

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedAddress: String
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    let title: String

    @StateObject private var viewModel = LocationPickerViewModel()
    @StateObject private var locationManager = FleetLocationManager()

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
    )
    @State private var showResults = false

    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: Full-screen map
                Map(position: $position) {}
                    .ignoresSafeArea(edges: .bottom)
                    .mapControls {
                        MapCompass()
                        MapUserLocationButton()
                        MapScaleView()
                    }
                    .onMapCameraChange(frequency: .onEnd) { context in
                        viewModel.updateMapCenter(context.region.center)
                    }

                // MARK: Fixed crosshair pin at screen center
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.red)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    Ellipse()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: 10, height: 4)
                        .offset(y: -2)
                }
                .allowsHitTesting(false)

                // MARK: Search bar pinned to top + dropdown results
                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    if showResults && !viewModel.completions.isEmpty {
                        resultsDropdown
                            .padding(.horizontal, 12)
                    }

                    Spacer()
                }

                // MARK: Bottom confirm bar
                VStack {
                    Spacer()
                    confirmBar
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                locationManager.requestLocation()

                // Wait up to 2s for location
                for _ in 0..<10 {
                    if locationManager.location != nil { break }
                    try? await Task.sleep(for: .milliseconds(200))
                }

                if !selectedAddress.isEmpty {
                    await viewModel.loadInitialAddress(selectedAddress)
                    if let coord = viewModel.selectedCoordinate {
                        position = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                } else if let loc = locationManager.location {
                    position = .region(MKCoordinateRegion(
                        center: loc.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    ))
                    viewModel.updateMapCenter(loc.coordinate)
                }
            }
            .onChange(of: viewModel.query) { _, _ in
                showResults = !viewModel.query.isEmpty
            }
            .onReceive(viewModel.$selectedCoordinate) { coord in
                guard let coord else { return }
                position = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
                showResults = false
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.body)

            TextField("Search address or place", text: $viewModel.query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.subheadline)

            if viewModel.isSearching {
                ProgressView().controlSize(.small)
            } else if !viewModel.query.isEmpty {
                Button {
                    viewModel.clearSearch()
                    showResults = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Results Dropdown

    private var resultsDropdown: some View {
        VStack(spacing: 0) {
            if let error = viewModel.searchError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.caption)
                    Text(error).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(viewModel.limitedCompletions) { item in
                    Button {
                        Task { await viewModel.selectCompletion(item.completion) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin")
                                .font(.caption)
                                .foregroundColor(.TechBlue)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if item.id != viewModel.limitedCompletions.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Confirm Bar

    private var confirmBar: some View {
        VStack(spacing: 8) {
            if !viewModel.selectedAddress.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.TechBlue)
                        .font(.body)
                    Text(viewModel.selectedAddress)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            } else {
                Text("Pan the map to select a location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            Button {
                selectedAddress = viewModel.selectedAddress
                selectedCoordinate = viewModel.selectedCoordinate
                dismiss()
            } label: {
                Text("Use This Location")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(viewModel.selectedAddress.isEmpty ? Color(.systemGray4) : Color.TechBlue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(viewModel.selectedAddress.isEmpty)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(.ultraThinMaterial)
    }
}

// MARK: - LocationPickerViewModel

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
        Array(completions.prefix(6)).enumerated().map {
            IdentifiableCompletion(id: $0.offset, completion: $0.element)
        }
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
            latitudinalMeters: 2_000_000,
            longitudinalMeters: 2_000_000
        )

        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] value in
                guard let self else { return }
                let trimmed = value.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    self.completions = []
                    self.isSearching = false
                    self.completer.queryFragment = ""
                } else {
                    self.isSearching = true
                    self.searchError = nil
                    self.completer.queryFragment = trimmed
                }
            }
            .store(in: &cancellables)
    }

    func loadInitialAddress(_ address: String) async {
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        selectedAddress = address
        if let placemark = try? await geocoder.geocodeAddressString(address).first,
           let loc = placemark.location {
            selectedCoordinate = loc.coordinate
        }
    }

    func updateMapCenter(_ coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        completer.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 100_000,
            longitudinalMeters: 100_000
        )

        reverseGeocodeTask?.cancel()
        reverseGeocodeTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            if let placemark = try? await geocoder.reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            ).first {
                let parts = [placemark.name, placemark.locality, placemark.administrativeArea]
                    .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                selectedAddress = parts.joined(separator: ", ")
            }
        }
    }

    func selectCompletion(_ completion: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: completion)
        if let response = try? await MKLocalSearch(request: request).start(),
           let item = response.mapItems.first {
            selectedCoordinate = item.location.coordinate
            let addr = [completion.title, completion.subtitle]
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: ", ")
            selectedAddress = addr
            query = completion.title
            completions = []
        }
    }

    func clearSearch() {
        query = ""
        completions = []
        isSearching = false
        searchError = nil
        completer.queryFragment = ""
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
        isSearching = false
        searchError = completions.isEmpty && !completer.queryFragment.isEmpty
            ? "No results found" : nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        isSearching = false
        completions = []
        searchError = "Search failed. Please try again."
    }
}

// MARK: - FleetLocationManager

@MainActor
class FleetLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.location = locations.last }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}
