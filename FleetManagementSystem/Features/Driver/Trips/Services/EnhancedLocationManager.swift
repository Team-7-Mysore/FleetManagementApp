import Foundation
import CoreLocation
import Combine
import Network
import Supabase

class EnhancedLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let client = SupabaseManager.shared.client
    private let networkMonitor = NWPathMonitor()
    
    // State
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var isMoving = false
    @Published var isOnline = true
    
    private var lastUploadedLocation: CLLocation?
    private var locationCache: [[String: Any]] = []
    private var vehicleId: UUID?
    private var tripId: UUID?
    
    // Adaptive Polling
    private var updateTimer: Timer?
    private let movingInterval: TimeInterval = 2.0
    private let idleInterval: TimeInterval = 30.0
    
    override init() {
        super.init()
        setupNetworkMonitoring()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = self?.isOnline == false
                self?.isOnline = path.status == .satisfied
                
                if wasOffline && self?.isOnline == true {
                    self?.flushCache()
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global())
    }
    
    func startTracking(vehicleId: UUID, tripId: UUID) {
        self.vehicleId = vehicleId
        self.tripId = tripId
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
        startAdaptiveTimer()
    }
    
    func stopTracking() {
        manager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func startAdaptiveTimer() {
        updateTimer?.invalidate()
        let interval = isMoving ? movingInterval : idleInterval
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.processCurrentLocation()
            self?.startAdaptiveTimer() // Reschedule with potentially new interval
        }
    }
    
    private func processCurrentLocation() {
        guard let location = manager.location else { return }
        
        let distance = lastUploadedLocation?.distance(from: location) ?? 100
        let isNowMoving = distance > 10 // 10 meters movement threshold
        
        if isMoving != isNowMoving {
            isMoving = isNowMoving
            // Timer will adapt on next reschedule
        }
        
        if isNowMoving || lastUploadedLocation == nil {
            uploadOrCache(location)
        }
    }
    
    private func uploadOrCache(_ location: CLLocation) {
        let entry: [String: Any] = [
            "vehicle_id": vehicleId?.uuidString.lowercased() ?? "",
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "timestamp": ISO8601DateFormatter().string(from: location.timestamp),
            "speed": location.speed
        ]
        
        if isOnline {
            Task {
                do {
                    try await client.from("vehicle_locations").insert(entry).execute()
                    self.lastUploadedLocation = location
                    print("✅ GPS Uploaded (Active)")
                } catch {
                    print("❌ Upload failed, caching point")
                    locationCache.append(entry)
                }
            }
        } else {
            print("🚀 Offline: Point cached")
            locationCache.append(entry)
        }
    }
    
    private func flushCache() {
        guard !locationCache.isEmpty else { return }
        let pointsToUpload = locationCache
        locationCache.removeAll()
        
        Task {
            do {
                try await client.from("vehicle_locations").insert(pointsToUpload).execute()
                print("📦 Cache Flushed: \(pointsToUpload.count) points synced")
            } catch {
                print("❌ Failed to flush cache: \(error)")
                self.locationCache.contentsOf(pointsToUpload) // Put them back
            }
        }
    }
    
    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.userLocation = location.coordinate
    }
}

extension Array {
    mutating func contentsOf(_ elements: [Element]) {
        self.append(contentsOf: elements)
    }
}
