import Foundation
import Combine

// MARK: - Driver Dashboard ViewModel
@MainActor
final class DriverDashboardViewModel: ObservableObject {
    @Published private(set) var assignedVehicle: Vehicle?
    @Published private(set) var activeTrip: Trip?
    @Published private(set) var upcomingTrips: [Trip] = []
    @Published private(set) var currentInspection: Inspection?
    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var unreadNotificationCount = 0
    @Published private(set) var totalMiles: Double = 0
    @Published private(set) var totalTrips: Int = 0
    @Published private(set) var fuelEfficiency: Double?

    private let user: User
    private let vehicleService = VehicleService.shared
    private let tripService = TripService.shared
    private let inspectionService = InspectionService.shared
    private let notificationService = NotificationService.shared
    private let fuelService = FuelService.shared

    init(user: User) {
        self.user = user
    }

    func loadData() {
        assignedVehicle = vehicleService.assignedVehicle(forDriver: user.id)
        activeTrip = tripService.activeTrip(forDriver: user.id)
        upcomingTrips = Array(tripService.upcomingTrips(forDriver: user.id).prefix(3))
        currentInspection = inspectionService.currentInspection(forDriver: user.id)
        notifications = notificationService.fetchNotifications(forUser: user.id)
        unreadNotificationCount = notificationService.unreadCount(forUser: user.id)
        totalMiles = tripService.totalMiles(forDriver: user.id)
        totalTrips = tripService.totalTrips(forDriver: user.id)

        if let vehicle = assignedVehicle {
            fuelEfficiency = fuelService.estimatedMPG(forVehicle: vehicle.id)
        }
    }

    func startTrip(_ trip: Trip) {
        tripService.startTrip(id: trip.id)
        loadData()
    }
}
