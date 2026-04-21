//import SwiftUI
//
//// MARK: - Driver Tab View
//struct DriverTabView: View {
//    let user: User
//    @EnvironmentObject private var router: AppRouter
//
//    var body: some View {
//        TabView {
//            Tab("Dashboard", systemImage: "house.fill") {
//                NavigationStack {
//                    DriverDashboardView(user: user)
//                }
//            }
//
//            Tab("Trips", systemImage: "map.fill") {
//                NavigationStack {
//                    TripListView(user: user)
//                }
//            }
//
//            Tab("Inspect", systemImage: "checklist") {
//                NavigationStack {
//                    VehicleInspectionView(user: user)
//                }
//            }
//
//            Tab("Fuel", systemImage: "fuelpump.fill") {
//                NavigationStack {
//                    FuelLogView(user: user)
//                }
//            }
//
//            Tab("Messages", systemImage: "message.fill") {
//                NavigationStack {
//                    ConversationListView(user: user)
//                }
//            }
//        }
//        .tint(AppTheme.primaryGreen)
//    }
//}
