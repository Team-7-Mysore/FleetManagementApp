import Foundation

struct DriverService {
    func fetchDashboardData() async throws -> DriverDashboardData {
        try await Task.sleep(for: .milliseconds(300))

        return DriverDashboardData(
            assignment: DriverAssignment(
                vehicleName: "Tata Ace EV",
                registrationNumber: "MH12 AB 4589",
                routeName: "Pune City Morning Loop",
                shiftWindow: "08:00 AM - 05:00 PM",
                startLocation: "Warehouse 04, Baner",
                destination: "7 delivery stops across Pune West",
                scheduledStart: "08:15 AM",
                cargoSummary: "Medical supplies and time-sensitive packages"
            ),
            stats: [
                DriverStat(title: "Today's Stops", value: "7", detail: "2 completed"),
                DriverStat(title: "Distance", value: "42 km", detail: "Planned route"),
                DriverStat(title: "Fuel Score", value: "92%", detail: "Efficient driving"),
                DriverStat(title: "Alerts", value: "1", detail: "Inspection follow-up")
            ],
            trips: [
                DriverTrip(
                    id: UUID(uuidString: "E57B0A34-DF32-495F-8A97-345D9B62F7B3") ?? UUID(),
                    title: "Morning Dispatch",
                    route: "Baner -> Aundh -> Shivajinagar",
                    schedule: "Started at 08:22 AM",
                    status: .active,
                    distance: "14 km remaining",
                    eta: "ETA 10:05 AM"
                ),
                DriverTrip(
                    id: UUID(uuidString: "7626CFD4-FF60-4FA3-A7A6-3383C332CF33") ?? UUID(),
                    title: "Afternoon Return",
                    route: "Camp -> Kothrud -> Baner",
                    schedule: "Scheduled for 02:30 PM",
                    status: .upcoming,
                    distance: "18 km",
                    eta: "ETA 04:10 PM"
                ),
                DriverTrip(
                    id: UUID(uuidString: "1682992A-1E7D-48D8-941B-C16A2D01D0BB") ?? UUID(),
                    title: "Depot Pickup",
                    route: "Baner -> Hinjawadi",
                    schedule: "Completed yesterday",
                    status: .completed,
                    distance: "26 km",
                    eta: "Closed successfully"
                )
            ],
            inspectionItems: [
                DriverInspectionItem(id: UUID(), title: "Brake check", detail: "Pedal response and parking brake", isCompleted: true),
                DriverInspectionItem(id: UUID(), title: "Tire pressure", detail: "All four tires within safe range", isCompleted: true),
                DriverInspectionItem(id: UUID(), title: "Lights and indicators", detail: "Headlamps, brakes, hazard, turn signals", isCompleted: false),
                DriverInspectionItem(id: UUID(), title: "Cargo seal", detail: "Verify rear compartment is locked", isCompleted: false)
            ],
            messages: [
                DriverMessage(
                    id: UUID(),
                    sender: "Fleet Manager",
                    subject: "Delay reported on stop 3",
                    preview: "Traffic near University Circle is building. Use the alternate lane if available.",
                    time: "09:12 AM",
                    priority: .high
                ),
                DriverMessage(
                    id: UUID(),
                    sender: "Maintenance Desk",
                    subject: "Inspection note acknowledged",
                    preview: "The low-beam lamp issue has been added to today's maintenance queue after shift close.",
                    time: "08:46 AM",
                    priority: .normal
                )
            ]
        )
    }
}
