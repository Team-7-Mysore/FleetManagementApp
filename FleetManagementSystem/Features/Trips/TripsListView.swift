
import SwiftUI


struct TripsListView: View {
   let profile: UserProfile?
   let onSignOut: () async -> Void

   @StateObject private var vm = TripListViewModel()
   @State private var showingProfile = false

   init(profile: UserProfile? = nil, onSignOut: @escaping () async -> Void = {}) {
       self.profile = profile
       self.onSignOut = onSignOut
   }


   var body: some View {
       NavigationStack {
           ZStack(alignment: .bottomTrailing) {
               ScrollView {
                   VStack(spacing: 20) {
                       // Fleet Overview Cards
                       fleetOverviewSection

                       // Ongoing Trips Section
                       ongoingTripsSection

                       // Vehicles in Maintenance Section
                       if !vm.vehiclesInMaintenance.isEmpty {
                           maintenanceSection
                       }
                   }
                   .padding(.horizontal, 16)
                   .padding(.top, 8)
                   .padding(.bottom, 100)
               }
               .background(Color(.systemGroupedBackground))
               .navigationTitle("Fleet Dashboard")
               .navigationBarTitleDisplayMode(.large)
               .toolbar {
                   ToolbarItemGroup(placement: .topBarTrailing) {
                       Button(action: {}) {
                           Image(systemName: "bell")
                               .font(.body.weight(.semibold))
                               .foregroundColor(.primary)
                       }
                       Button(action: {
                           showingProfile = true
                       }) {
                           Image(systemName: "person.circle.fill")
                               .font(.title3)
                               .foregroundColor(.TechBlue)
                       }
                   }
               }
               .task {
                   guard vm.trips.isEmpty else { return }
                   await vm.fetchTrips()
               }
               .refreshable {
                   await vm.fetchTrips()
               }
               .sheet(isPresented: $showingProfile) {
                   FleetManagerProfileView(profile: profile, onSignOut: onSignOut)
                       .presentationDetents([.medium])
                       .presentationDragIndicator(.visible)
               }


               floatingActionButton
           }
       }
   }

   // MARK: - Fleet Overview Section
   private var fleetOverviewSection: some View {
       VStack(alignment: .leading, spacing: 12) {
           Text("Fleet Overview")
               .font(.title3.weight(.semibold))
               .foregroundColor(.primary)

           HStack(spacing: 12) {
               overviewCard(
                   title: "Available Drivers",
                   value: "\(vm.availableDriverCount)",
                   icon: "person.2.fill",
                   color: Color(hex: "#4A90E2")
               )

               overviewCard(
                   title: "Available Vehicles",
                   value: "\(vm.availableVehicleCount)",
                   icon: "car.2.fill",
                   color: Color(hex: "#50C878")
               )
           }
       }
   }

   private func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
       VStack(spacing: 16) {
           HStack(alignment: .center, spacing: 5){
               Image(systemName: icon)
                   .font(.system(size: 16))
                   .foregroundColor(color)

               Text(title)
                   .font(.subheadline)
                   .foregroundColor(.secondary)
                   //.multilineTextAlignment(.center)
           }

           Text(value)
               .font(.system(size: 32, weight: .bold, design: .rounded))
               .foregroundColor(.primary)

       }
       .frame(maxWidth: .infinity)
       .padding(.vertical, 16)
       .padding(.horizontal, 10)
       .background(Color(.secondarySystemGroupedBackground))
       .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
       .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
   }

   // MARK: - Ongoing Trips Section
   private var ongoingTripsSection: some View {
       VStack(alignment: .leading, spacing: 12) {
           HStack {
               Text("Ongoing Trips")
                   .font(.title3.weight(.semibold))
                   .foregroundColor(.primary)

               Spacer()

               NavigationLink("View All", destination: AllTripsView())
                   .font(.subheadline.weight(.semibold))
                   .foregroundColor(.TechBlue)
           }

           if vm.isLoading {
               loadingState
           } else if vm.filteredTrips.isEmpty {
               emptyTripsState
           } else {
               ForEach(Array(vm.filteredTrips.prefix(3))) { trip in
                   EnhancedTripCard(trip: trip)
               }
           }
       }
   }

   // MARK: - Maintenance Section
   private var maintenanceSection: some View {
       VStack(alignment: .leading, spacing: 12) {
           HStack {
               Text("Vehicles in Maintenance")
                   .font(.title3.weight(.semibold))
                   .foregroundColor(.primary)

               Spacer()

               Text("\(vm.maintenanceVehicleCount)")
                   .font(.subheadline.weight(.bold))
                   .foregroundColor(.white)
                   .padding(.horizontal, 12)
                   .padding(.vertical, 6)
                   .background(Color.orange)
                   .clipShape(Capsule())
           }

           ForEach(Array(vm.vehiclesInMaintenance.prefix(3))) { workOrder in
               MaintenanceVehicleCard(workOrder: workOrder)
           }
       }
   }

   private var loadingState: some View {
       HStack(spacing: 12) {
           ProgressView()
           Text("Loading trips…")
               .font(.body)
               .foregroundStyle(.secondary)
       }
       .frame(maxWidth: .infinity)
       .padding(.vertical, 40)
   }

   private var emptyTripsState: some View {
       VStack(spacing: 12) {
           Image(systemName: "shippingbox")
               .font(.system(size: 48))
               .foregroundColor(.secondary)

           Text("No Ongoing Trips")
               .font(.headline)
               .foregroundColor(.primary)

           Text("Active trips will appear here")
               .font(.subheadline)
               .foregroundColor(.secondary)
       }
       .frame(maxWidth: .infinity)
       .padding(.vertical, 40)
       .background(Color(.secondarySystemGroupedBackground))
       .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
   }

   private var floatingActionButton: some View {
       NavigationLink(destination: CreateTripView()) {
           Image(systemName: "plus")
               .font(.title2.weight(.bold))
               .foregroundColor(.white)
               .frame(width: 60, height: 60)
               .background(
                   LinearGradient(
                       colors: [Color.TechBlue, Color.TechBlue.opacity(0.8)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing
                   )
               )
               .clipShape(Circle())
               .shadow(color: Color.TechBlue.opacity(0.4), radius: 12, x: 0, y: 6)
       }
       .padding(.trailing, 20)
       .padding(.bottom, 24)
   }
}


// MARK: - Enhanced Trip Card
struct EnhancedTripCard: View {
   let trip: Trip

   var body: some View {
       VStack(alignment: .leading, spacing: 16) {
           // Header with tracking number and status
           HStack {
               VStack(alignment: .leading, spacing: 4) {
                   Text("Tracking Number")
                       .font(.caption)
                       .foregroundColor(.white.opacity(0.8))

                   Text(trip.displayTripID)
                       .font(.title3.weight(.bold))
                       .foregroundColor(.white)
               }

               Spacer()

               statusBadge
           }

           // Progress indicator
           tripProgressView

           // Route information
           HStack(spacing: 20) {
               VStack(alignment: .leading, spacing: 4) {
                   Text("From")
                       .font(.caption)
                       .foregroundColor(.white.opacity(0.7))
                   Text(trip.originText)
                       .font(.subheadline.weight(.semibold))
                       .foregroundColor(.white)
               }

               Image(systemName: "arrow.right")
                   .foregroundColor(.white.opacity(0.6))

               VStack(alignment: .leading, spacing: 4) {
                   Text("To")
                       .font(.caption)
                       .foregroundColor(.white.opacity(0.7))
                   Text(trip.destinationText)
                       .font(.subheadline.weight(.semibold))
                       .foregroundColor(.white)
               }

               Spacer()

               VStack(alignment: .trailing, spacing: 4) {
                   Text("Arrival date")
                       .font(.caption)
                       .foregroundColor(.white.opacity(0.7))
                   Text(trip.formattedEstimatedDate)
                       .font(.subheadline.weight(.semibold))
                       .foregroundColor(.white)
               }
           }
       }
       .padding(20)
       .background(
           LinearGradient(
               colors: gradientColors,
               startPoint: .topLeading,
               endPoint: .bottomTrailing
           )
       )
       .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
       .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
   }

   private var statusBadge: some View {
       Text(trip.normalisedStatus.displayTitle)
           .font(.caption.weight(.bold))
           .foregroundColor(.white)
           .padding(.horizontal, 12)
           .padding(.vertical, 6)
           .background(Color.black.opacity(0.3))
           .clipShape(Capsule())
   }

   private var tripProgressView: some View {
       HStack(spacing: 0) {
           ForEach(0..<4) { index in
               Circle()
                   .fill(progressColor(for: index))
                   .frame(width: 12, height: 12)

               if index < 3 {
                   Rectangle()
                       .fill(progressColor(for: index))
                       .frame(height: 2)
               }
           }
       }
   }

   private func progressColor(for index: Int) -> Color {
       let status = trip.normalisedStatus
       switch status {
       case .scheduled:
           return index == 0 ? .white : .white.opacity(0.3)
       case .inProgress:
           return index <= 1 ? .white : .white.opacity(0.3)
       case .inTransit:
           return index <= 2 ? .white : .white.opacity(0.3)
       case .completed:
           return .white
       default:
           return .white.opacity(0.3)
       }
   }

   private var gradientColors: [Color] {
       switch trip.normalisedStatus {
       case .inTransit:
           return [Color(hex: "#FF6B9D"), Color(hex: "#FFA07A")]
       case .inProgress:
           return [Color(hex: "#A8E6CF"), Color(hex: "#7FD8BE")]
       case .scheduled:
           return [Color(hex: "#FFD93D"), Color(hex: "#FFC857")]
       case .completed:
           return [Color(hex: "#6BCF7F"), Color(hex: "#4CAF50")]
       default:
           return [Color(hex: "#B0BEC5"), Color(hex: "#90A4AE")]
       }
   }
}


// MARK: - Maintenance Vehicle Card
struct MaintenanceVehicleCard: View {
   let workOrder: WorkOrder

   var body: some View {
       HStack(spacing: 16) {
           // Vehicle icon
           ZStack {
               Circle()
                   .fill(Color.orange.opacity(0.15))
                   .frame(width: 50, height: 50)

               Image(systemName: "wrench.and.screwdriver.fill")
                   .font(.title3)
                   .foregroundColor(.orange)
           }

           VStack(alignment: .leading, spacing: 4) {
               Text(workOrder.vehicleName ?? workOrder.vehicleVin)
                   .font(.headline)
                   .foregroundColor(.primary)

               Text(workOrder.issueTitle)
                   .font(.subheadline)
                   .foregroundColor(.secondary)
                   .lineLimit(1)
           }

           Spacer()

           VStack(alignment: .trailing, spacing: 4) {
               Text(workOrder.status.rawValue.capitalized)
                   .font(.caption.weight(.semibold))
                   .foregroundColor(.orange)

               if let cost = workOrder.estCost {
                   Text("$\(Int(cost))")
                       .font(.caption)
                       .foregroundColor(.secondary)
               }
           }
       }
       .padding(16)
       .background(Color(.secondarySystemGroupedBackground))
       .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
   }
}


// MARK: - Hex Color Extension
extension Color {
   init(hex: String) {
       let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
       var int: UInt64 = 0
       Scanner(string: hex).scanHexInt64(&int)


       let a, r, g, b: UInt64
       switch hex.count {
       case 6:
           (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
       case 8:
           (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
       default:
           (a, r, g, b) = (255, 0, 0, 0)
       }


       self.init(
           .sRGB,
           red: Double(r) / 255,
           green: Double(g) / 255,
           blue: Double(b) / 255,
           opacity: Double(a) / 255
       )
   }
}


#Preview {
   TripsListView()
}
