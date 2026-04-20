import SwiftUI
import MapKit
// MARK: - Active Trip View
struct ActiveTripView: View {
    let trip: Trip
    let user: User
    @EnvironmentObject private var router: AppRouter

    @State private var elapsedTime: TimeInterval = 0
    @State private var showEndTripConfirmation = false
    @State private var showReportIssue = false
    @State private var timer: Timer?

    // MapKit State
    @State private var route: MKRoute?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @StateObject private var locationManager = LocationManager()
    
    // Database points with fallbacks to demonstration points
    var startPoint: CLLocationCoordinate2D {
        if let coord = trip.startCoordinate {
            return CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
        }
        return CLLocationCoordinate2D(latitude: 12.3060, longitude: 76.6547)
    }
    
    var endPoint: CLLocationCoordinate2D {
        if let coord = trip.endCoordinate {
            return CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
        }
        return CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Map
            Map(position: $cameraPosition) {
                UserAnnotation()
                
                Marker("Start", coordinate: startPoint)
                    .tint(.green)
                
                Marker("Destination", coordinate: endPoint)
                    .tint(.red)
                
                if let route = route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 5)
                }
            }
            .mapControls {
                MapUserLocationButton()
            }
            .frame(maxHeight: .infinity)

            // MARK: - Bottom Panel
            VStack(spacing: 16) {
                // Trip info bar
                HStack(spacing: 24) {
                    tripInfoItem(value: trip.formattedDistance, label: "Distance")
                    Divider().frame(height: 36)
                    tripInfoItem(value: trip.formattedETA, label: "ETA")
                    Divider().frame(height: 36)
                    tripInfoItem(value: formattedElapsed, label: "Elapsed")
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Action buttons
                VStack(spacing: 12) {
                    // Navigate Button
                    Button { openInMaps() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                            Text("Start Navigation")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    HStack(spacing: 12) {
                        Button { showReportIssue = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                Text("Report Issue")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.statusDanger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppTheme.statusDanger.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button { showEndTripConfirmation = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                Text("End Trip")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppTheme.primaryGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal)

                // Destination bar
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(AppTheme.primaryGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Destination")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(trip.endLocation)
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Active Trip")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("End Trip", isPresented: $showEndTripConfirmation) {
            Button("End Trip", role: .destructive) {
                router.path.append(AppRoute.vehicleInspection(trip, type: .postTrip))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this trip?")
        }
        .sheet(isPresented: $showReportIssue) {
            ReportIssueView(user: user, vehicle: nil)
        }
        .onAppear { 
            startTimer()
            createRoute()
            locationManager.requestLocation()
        }
        .onDisappear { stopTimer() }
    }


    private func tripInfoItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedElapsed: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        if let startTime = trip.startTime {
            elapsedTime = Date().timeIntervalSince(startTime)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let startTime = trip.startTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Map Logic
    private func createRoute() {
        let sourcePlacemark = MKPlacemark(coordinate: startPoint)
        let destPlacemark = MKPlacemark(coordinate: endPoint)
        
        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destItem = MKMapItem(placemark: destPlacemark)
        
        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destItem
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            
            if let error = error {
                print("Error getting route: \(error.localizedDescription)")
                return
            }
            
            guard let response = response else {
                print("No response received")
                return
            }
            
            guard let route = response.routes.first else {
                print("No routes found")
                return
            }
            
            DispatchQueue.main.async {
                self.route = route
                let rect = route.polyline.boundingMapRect
                let paddedRect = rect.insetBy(dx: -rect.size.width * 0.12,
                                              dy: -rect.size.height * 0.12)
                let region = MKCoordinateRegion(paddedRect)

                self.cameraPosition = .region(region)
            }
        }
    }
    
    private func openInMaps() {
        let destinationPlacemark = MKPlacemark(coordinate: endPoint)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        destinationItem.name = trip.endLocation
        
        destinationItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

// MARK: - LocationManager
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    private let manager = CLLocationManager()
    
    @Published var userLocation: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        
        switch manager.authorizationStatus {
            
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Authorized")
            manager.startUpdatingLocation()
            
        case .denied, .restricted:
            print("❌ Permission denied")
            
        default:
            break
        }
    }
    
    // Delegate method (this is where updates come)
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("📍 didUpdateLocations called")
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            print("📍 New location:", location.coordinate)
            self.userLocation = location.coordinate
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
