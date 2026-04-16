import Foundation

struct DriverDashboardData: Equatable {
    let assignment: DriverAssignment
    let stats: [DriverStat]
    let trips: [DriverTrip]
    let inspectionItems: [DriverInspectionItem]
    let messages: [DriverMessage]
}
