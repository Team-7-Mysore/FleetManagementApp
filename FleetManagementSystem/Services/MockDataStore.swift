import Foundation

// MARK: - Mock Data Store
// Central in-memory data store with realistic sample data.
// All services read from / write to this singleton.

final class MockDataStore {
    static let shared = MockDataStore()

    // MARK: - Stored Data
    var users: [User]
    var vehicles: [Vehicle]
    var trips: [Trip]
    var maintenanceTasks: [MaintenanceTask]
    var inspections: [Inspection]
    var fuelLogs: [FuelLog]
    var messages: [Message]
    var notifications: [AppNotification]

    // MARK: - Fixed IDs for relationships
    static let driverJohnId      = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let driverSarahId     = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let fleetManagerId    = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let maintenanceMikeId = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    static let maintenanceLisaId = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!

    static let vehicleTruck702Id = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    static let vehicleVan305Id   = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    static let vehicleSedanId    = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
    static let vehicleSUVId      = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
    static let vehiclePickupId   = UUID(uuidString: "00000000-0000-0000-0000-000000000105")!

    private init() {
        let cal = Calendar.current
        let now = Date()

        // ─── Users ─────────────────────────────────────────
        users = [
            User(id: Self.driverJohnId, firstName: "John", lastName: "Carter",
                 email: "john.carter@fms.com", role: .driver, phone: "+1 555-0101",
                 isActive: true, joinDate: cal.date(byAdding: .month, value: -14, to: now)!),

            User(id: Self.driverSarahId, firstName: "Sarah", lastName: "Mitchell",
                 email: "sarah.mitchell@fms.com", role: .driver, phone: "+1 555-0102",
                 isActive: true, joinDate: cal.date(byAdding: .month, value: -8, to: now)!),

            User(id: Self.fleetManagerId, firstName: "Robert", lastName: "Anderson",
                 email: "robert.anderson@fms.com", role: .fleetManager, phone: "+1 555-0201",
                 isActive: true, joinDate: cal.date(byAdding: .year, value: -3, to: now)!),

            User(id: Self.maintenanceMikeId, firstName: "Mike", lastName: "Thompson",
                 email: "mike.thompson@fms.com", role: .maintenance, phone: "+1 555-0301",
                 isActive: true, joinDate: cal.date(byAdding: .month, value: -20, to: now)!),

            User(id: Self.maintenanceLisaId, firstName: "Lisa", lastName: "Chen",
                 email: "lisa.chen@fms.com", role: .maintenance, phone: "+1 555-0302",
                 isActive: true, joinDate: cal.date(byAdding: .month, value: -6, to: now)!)
        ]

        // ─── Vehicles ──────────────────────────────────────
        vehicles = [
            Vehicle(id: Self.vehicleTruck702Id, name: "Truck #702",
                    make: "Ford", model: "F-150", year: 2024, vin: "1FTEW1EP5NFA00702",
                    licensePlate: "FMS-702", registrationNumber: "REG-702",
                    status: .inUse, mileage: 34_520, fuelLevel: 0.65,
                    fuelType: .gasoline, assignedDriverId: Self.driverJohnId,
                    lastMaintenanceDate: cal.date(byAdding: .day, value: -22, to: now),
                    nextMaintenanceDate: cal.date(byAdding: .day, value: 8, to: now),
                    imageSystemName: "truck.box.fill"),

            Vehicle(id: Self.vehicleVan305Id, name: "Van #305",
                    make: "Mercedes", model: "Sprinter", year: 2023, vin: "WDB9066331S305001",
                    licensePlate: "FMS-305", registrationNumber: "REG-305",
                    status: .available, mileage: 52_180, fuelLevel: 0.82,
                    fuelType: .diesel, assignedDriverId: Self.driverSarahId,
                    lastMaintenanceDate: cal.date(byAdding: .day, value: -10, to: now),
                    nextMaintenanceDate: cal.date(byAdding: .day, value: 20, to: now),
                    imageSystemName: "box.truck.fill"),

            Vehicle(id: Self.vehicleSedanId, name: "Sedan #118",
                    make: "Toyota", model: "Camry", year: 2024, vin: "4T1BF1FK5EU118001",
                    licensePlate: "FMS-118", registrationNumber: "REG-118",
                    status: .available, mileage: 18_900, fuelLevel: 0.45,
                    fuelType: .hybrid, assignedDriverId: nil,
                    lastMaintenanceDate: cal.date(byAdding: .day, value: -5, to: now),
                    nextMaintenanceDate: cal.date(byAdding: .day, value: 25, to: now),
                    imageSystemName: "car.fill"),

            Vehicle(id: Self.vehicleSUVId, name: "SUV #410",
                    make: "Chevrolet", model: "Tahoe", year: 2023, vin: "1GNSKBKC0PR410001",
                    licensePlate: "FMS-410", registrationNumber: "REG-410",
                    status: .maintenance, mileage: 67_300, fuelLevel: 0.30,
                    fuelType: .gasoline, assignedDriverId: nil,
                    lastMaintenanceDate: cal.date(byAdding: .day, value: -2, to: now),
                    nextMaintenanceDate: cal.date(byAdding: .day, value: 5, to: now),
                    imageSystemName: "suv.side.fill"),

            Vehicle(id: Self.vehiclePickupId, name: "Pickup #550",
                    make: "Ram", model: "1500", year: 2024, vin: "1C6SRFFT0PN550001",
                    licensePlate: "FMS-550", registrationNumber: "REG-550",
                    status: .outOfService, mileage: 89_100, fuelLevel: 0.10,
                    fuelType: .diesel, assignedDriverId: nil,
                    lastMaintenanceDate: cal.date(byAdding: .day, value: -30, to: now),
                    nextMaintenanceDate: nil,
                    imageSystemName: "truck.pickup.side")
        ]

        // ─── Trips ──────────────────────────────────────────
        let todayMorning = cal.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        let todayAfternoon = cal.date(bySettingHour: 14, minute: 30, second: 0, of: now)!

        trips = [
            // Active trip for John
            Trip(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                 startLocation: "Central Port", endLocation: "Logistics Hub East",
                 startTime: cal.date(byAdding: .hour, value: -1, to: now),
                 endTime: nil,
                 scheduledStartTime: todayMorning,
                 distance: 142, estimatedDuration: 8100,
                 fuelUsed: nil, status: .inProgress, notes: "Priority delivery",
                 route: [Coordinate(latitude: 40.7128, longitude: -74.0060),
                         Coordinate(latitude: 40.7580, longitude: -73.8855)]),

            // Upcoming trip for John
            Trip(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                 startLocation: "Logistics Hub East", endLocation: "Warehouse District B",
                 startTime: nil, endTime: nil,
                 scheduledStartTime: todayAfternoon,
                 distance: 58, estimatedDuration: 3600,
                 fuelUsed: nil, status: .planned, notes: "Deliver to Gate 14",
                 route: []),

            // Tomorrow trip for John
            Trip(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                 startLocation: "Main Depot", endLocation: "North Terminal",
                 startTime: nil, endTime: nil,
                 scheduledStartTime: cal.date(byAdding: .day, value: 1, to: todayMorning)!,
                 distance: 95, estimatedDuration: 5400,
                 fuelUsed: nil, status: .planned, notes: "",
                 route: []),

            // Completed trip (yesterday) for John
            Trip(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                 startLocation: "South Yard", endLocation: "Central Port",
                 startTime: cal.date(byAdding: .day, value: -1, to: todayMorning),
                 endTime: cal.date(byAdding: .hour, value: 3, to: cal.date(byAdding: .day, value: -1, to: todayMorning)!),
                 scheduledStartTime: cal.date(byAdding: .day, value: -1, to: todayMorning)!,
                 distance: 78, estimatedDuration: 4200,
                 fuelUsed: 6.2, status: .completed, notes: "Completed on time",
                 route: []),

            // Completed trip (2 days ago)
            Trip(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                 startLocation: "Airport Cargo", endLocation: "Downtown Hub",
                 startTime: cal.date(byAdding: .day, value: -2, to: todayMorning),
                 endTime: cal.date(byAdding: .hour, value: 2, to: cal.date(byAdding: .day, value: -2, to: todayMorning)!),
                 scheduledStartTime: cal.date(byAdding: .day, value: -2, to: todayMorning)!,
                 distance: 45, estimatedDuration: 2700,
                 fuelUsed: 3.8, status: .completed, notes: "",
                 route: []),

            // Trip for Sarah
            Trip(id: UUID(), vehicleId: Self.vehicleVan305Id, driverId: Self.driverSarahId,
                 startLocation: "Metro Center", endLocation: "East Side Depot",
                 startTime: nil, endTime: nil,
                 scheduledStartTime: todayAfternoon,
                 distance: 32, estimatedDuration: 2400,
                 fuelUsed: nil, status: .planned, notes: "",
                 route: [])
        ]

        // ─── Maintenance Tasks ────────────────────────────
        maintenanceTasks = [
            MaintenanceTask(id: UUID(), vehicleId: Self.vehicleTruck702Id,
                            type: .oilChange, description: "Regular oil change at 35,000 mi",
                            scheduledDate: cal.date(byAdding: .day, value: 8, to: now)!,
                            completedDate: nil, status: .scheduled, assignedPersonnelId: Self.maintenanceMikeId,
                            priority: .medium, cost: nil, partsUsed: [], laborHours: nil, notes: ""),

            MaintenanceTask(id: UUID(), vehicleId: Self.vehicleSUVId,
                            type: .brakeService, description: "Front and rear brake pad replacement",
                            scheduledDate: cal.date(byAdding: .day, value: -2, to: now)!,
                            completedDate: nil, status: .inProgress, assignedPersonnelId: Self.maintenanceMikeId,
                            priority: .high, cost: nil, partsUsed: ["Brake pads (front)", "Brake pads (rear)"],
                            laborHours: nil, notes: "Vehicle currently in maintenance bay"),

            MaintenanceTask(id: UUID(), vehicleId: Self.vehicleTruck702Id,
                            type: .tireRotation, description: "Routine tire rotation",
                            scheduledDate: cal.date(byAdding: .day, value: -22, to: now)!,
                            completedDate: cal.date(byAdding: .day, value: -22, to: now),
                            status: .completed, assignedPersonnelId: Self.maintenanceLisaId,
                            priority: .low, cost: 45.0, partsUsed: [], laborHours: 0.5, notes: "Completed without issues")
        ]

        // ─── Inspections ───────────────────────────────────
        inspections = [
            Inspection(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                       type: .preTrip, date: now,
                       items: Self.makeInspectionItems(completed: 5, total: 8),
                       overallNotes: "", isSubmitted: false),

            Inspection(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                       type: .postTrip,
                       date: cal.date(byAdding: .day, value: -1, to: now)!,
                       items: Self.makeInspectionItems(completed: 8, total: 8),
                       overallNotes: "All clear, vehicle in good condition", isSubmitted: true),

            Inspection(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                       type: .preTrip,
                       date: cal.date(byAdding: .day, value: -1, to: now)!,
                       items: Self.makeInspectionItems(completed: 8, total: 8),
                       overallNotes: "", isSubmitted: true)
        ]

        // ─── Fuel Logs ─────────────────────────────────────
        fuelLogs = [
            FuelLog(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                    date: cal.date(byAdding: .day, value: -1, to: now)!,
                    gallons: 12.5, costPerGallon: 3.89, totalCost: 48.63,
                    mileageAtFill: 34_450, location: "Shell Express - Central Port"),

            FuelLog(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                    date: cal.date(byAdding: .day, value: -4, to: now)!,
                    gallons: 14.2, costPerGallon: 3.79, totalCost: 53.82,
                    mileageAtFill: 34_200, location: "BP Station - Highway 9"),

            FuelLog(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                    date: cal.date(byAdding: .day, value: -8, to: now)!,
                    gallons: 11.8, costPerGallon: 3.92, totalCost: 46.26,
                    mileageAtFill: 33_950, location: "Exxon - South Yard"),

            FuelLog(id: UUID(), vehicleId: Self.vehicleTruck702Id, driverId: Self.driverJohnId,
                    date: cal.date(byAdding: .day, value: -12, to: now)!,
                    gallons: 13.0, costPerGallon: 3.85, totalCost: 50.05,
                    mileageAtFill: 33_700, location: "Chevron - Logistics Hub")
        ]

        // ─── Messages ──────────────────────────────────────
        messages = [
            Message(id: UUID(), senderId: Self.fleetManagerId, receiverId: Self.driverJohnId,
                    content: "John, your route for tomorrow has been updated. Please check the trip details.",
                    timestamp: cal.date(byAdding: .hour, value: -2, to: now)!, isRead: false),

            Message(id: UUID(), senderId: Self.driverJohnId, receiverId: Self.fleetManagerId,
                    content: "Got it, thanks Robert. I'll review it tonight.",
                    timestamp: cal.date(byAdding: .hour, value: -1, to: now)!, isRead: true),

            Message(id: UUID(), senderId: Self.maintenanceMikeId, receiverId: Self.driverJohnId,
                    content: "Hey John, noticed your truck is due for an oil change next week. I'll schedule it.",
                    timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true),

            Message(id: UUID(), senderId: Self.driverJohnId, receiverId: Self.maintenanceMikeId,
                    content: "Thanks Mike! Let me know when to bring it in.",
                    timestamp: cal.date(byAdding: .hour, value: -20, to: now)!, isRead: true),

            Message(id: UUID(), senderId: Self.fleetManagerId, receiverId: Self.driverJohnId,
                    content: "Great job on yesterday's deliveries. The client was very satisfied with the timing.",
                    timestamp: cal.date(byAdding: .day, value: -1, to: now)!, isRead: true)
        ]

        // ─── Notifications ─────────────────────────────────
        notifications = [
            AppNotification(id: UUID(), userId: Self.driverJohnId,
                            title: "New Trip Assigned", body: "You have a new trip scheduled for today at 2:30 PM.",
                            type: .tripAssigned, isRead: false, timestamp: cal.date(byAdding: .hour, value: -3, to: now)!,
                            relatedId: nil),

            AppNotification(id: UUID(), userId: Self.driverJohnId,
                            title: "Maintenance Reminder", body: "Truck #702 oil change due in 8 days.",
                            type: .maintenance, isRead: false, timestamp: cal.date(byAdding: .hour, value: -5, to: now)!,
                            relatedId: Self.vehicleTruck702Id),

            AppNotification(id: UUID(), userId: Self.driverJohnId,
                            title: "Pre-Trip Inspection", body: "Please complete your pre-trip inspection before departure.",
                            type: .inspectionDue, isRead: true, timestamp: cal.date(byAdding: .hour, value: -6, to: now)!,
                            relatedId: nil),

            AppNotification(id: UUID(), userId: Self.driverJohnId,
                            title: "Fuel Level Low", body: "Truck #702 fuel level is at 65%. Consider refueling soon.",
                            type: .fuelReminder, isRead: true, timestamp: cal.date(byAdding: .day, value: -1, to: now)!,
                            relatedId: Self.vehicleTruck702Id),

            AppNotification(id: UUID(), userId: Self.driverJohnId,
                            title: "New Message", body: "Robert Anderson sent you a message.",
                            type: .message, isRead: true, timestamp: cal.date(byAdding: .hour, value: -2, to: now)!,
                            relatedId: nil)
        ]
    }

    // MARK: - Inspection Item Generator
    private static func makeInspectionItems(completed: Int, total: Int) -> [InspectionItem] {
        let allItems: [(String, String)] = [
            ("Tires & Wheels", "Exterior"),
            ("Brakes", "Safety"),
            ("Lights & Signals", "Exterior"),
            ("Mirrors", "Exterior"),
            ("Horn", "Safety"),
            ("Windshield & Wipers", "Exterior"),
            ("Fluid Levels", "Engine"),
            ("Seat Belt", "Safety")
        ]
        return allItems.prefix(total).enumerated().map { index, item in
            InspectionItem(id: UUID(), name: item.0, category: item.1,
                           status: index < completed ? .pass : .pending,
                           notes: "")
        }
    }
}
