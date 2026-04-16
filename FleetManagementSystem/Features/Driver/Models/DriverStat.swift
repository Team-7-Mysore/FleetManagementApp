import Foundation

struct DriverStat: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
}
