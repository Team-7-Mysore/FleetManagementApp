import SwiftUI

// MARK: - Driver Dashboard View
struct DriverDashboardView: View {
    let user: User
    @StateObject private var vm: DriverDashboardViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var showNotifications = false
    @State private var showProfile = false

    init(user: User) {
        self.user = user
        _vm = StateObject(wrappedValue: DriverDashboardViewModel(user: user))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Active Route Card
                if let trip = vm.activeTrip {
                    activeRouteCard(trip)
                } else if let next = vm.upcomingTrips.first {
                    nextTripCard(next)
                }

                // MARK: - Quick Actions
                quickActionsRow



                // MARK: - Vehicle Info
                if let vehicle = vm.assignedVehicle {
                    vehicleCard(vehicle)
                }

                // MARK: - Stats Row
                statsRow

                // MARK: - Upcoming Trips
                if !vm.upcomingTrips.isEmpty {
                    upcomingTripsSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("Dashboard")
        .toolbar {

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button { showNotifications = true } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.body)
                                .foregroundStyle(.primary)
                            if vm.unreadNotificationCount > 0 {
                                Circle()
                                    .fill(AppTheme.statusDanger)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }

                    Button { showProfile = true } label: {
                        Circle()
                            .fill(AppTheme.primaryGreen)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text(user.initials)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                    }
                }
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationListView(user: user)
        }
        .sheet(isPresented: $showProfile) {
            DriverProfileView(user: user)
                .environmentObject(router)
        }
        .onAppear { vm.loadData() }
    }

    // MARK: - Active Route Card
    @ViewBuilder
    private func activeRouteCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                StatusBadge(text: "Active Route", color: AppTheme.primaryGreen)
                Spacer()
                Image(systemName: "location.fill")
                    .foregroundStyle(AppTheme.primaryGreen)
            }

            HStack(alignment: .top) {
                // Route path
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Circle()
                            .stroke(AppTheme.primaryGreen, lineWidth: 2)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("FROM")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(trip.startLocation)
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    // Dotted line
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(AppTheme.primaryGreen.opacity(0.3))
                            .frame(width: 2, height: 16)
                            .padding(.leading, 5)
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.primaryGreen)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("TO")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(trip.endLocation)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                Spacer()

                // Distance & ETA
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(trip.distance))")
                            .font(.title.weight(.bold))
                        Text("mi")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(trip.formattedETA + " left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // End Trip Button
            NavigationLink(value: AppRoute.activeTrip(trip)) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("View Active Trip")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(AppTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .cardStyle()
    }

    // MARK: - Next Trip Card (when no active trip)
    @ViewBuilder
    private func nextTripCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                StatusBadge(text: "Next Trip", color: AppTheme.statusInfo)
                Spacer()
                Text(trip.scheduledStartTime, style: .time)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Circle()
                            .stroke(AppTheme.primaryGreen, lineWidth: 2)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("FROM")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(trip.startLocation)
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(AppTheme.primaryGreen.opacity(0.3))
                            .frame(width: 2, height: 12)
                            .padding(.leading, 5)
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.primaryGreen)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("TO")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(trip.endLocation)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(trip.distance))")
                            .font(.title.weight(.bold))
                        Text("mi")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(trip.formattedETA)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Start Inspection Button
            NavigationLink(value: AppRoute.vehicleInspection(trip)) {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                    Text("START INSPECTION")
                        .font(.headline.weight(.bold))
                        .tracking(0.5)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(AppTheme.primaryGreen)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            }
        }
        .padding(18)
        .cardStyle()
    }

    // MARK: - Quick Actions
    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            NavigationLink(value: AppRoute.vehicleInspection(nil)) {
                quickActionItem(icon: "checklist", title: "Inspect", color: AppTheme.primaryGreen)
            }

            NavigationLink {
                TripListView(user: user)
            } label: {
                quickActionItem(icon: "map", title: "Trips", color: AppTheme.statusInfo)
            }

            NavigationLink {
                FuelLogView(user: user)
            } label: {
                quickActionItem(icon: "fuelpump", title: "Fuel", color: AppTheme.statusWarning)
            }

            NavigationLink {
                ReportIssueView(user: user, vehicle: vm.assignedVehicle)
            } label: {
                quickActionItem(icon: "exclamationmark.triangle", title: "Report", color: AppTheme.statusDanger)
            }
        }
    }

    private func quickActionItem(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .cardStyle()
    }

    // MARK: - Inspection Card
    @ViewBuilder
    private func inspectionCard(_ inspection: Inspection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: inspection.completionPercentage)
                        .stroke(AppTheme.primaryGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(inspection.completionPercentage * 100))%")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.primaryGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(inspection.type.rawValue) Inspection")
                        .font(.subheadline.weight(.semibold))
                    Text("\(inspection.pendingCount) item\(inspection.pendingCount == 1 ? "" : "s") remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink(value: AppRoute.vehicleInspection(nil)) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Vehicle Card
    @ViewBuilder
    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: vehicle.imageSystemName)
                    .font(.title2)
                    .foregroundStyle(AppTheme.primaryGreen)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.lightGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.name)
                        .font(.subheadline.weight(.semibold))
                    Text("\(vehicle.make) \(vehicle.model) • \(String(vehicle.year))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(
                    text: vehicle.status.rawValue,
                    color: vehicle.status == .inUse ? AppTheme.primaryGreen :
                           vehicle.status == .maintenance ? AppTheme.statusWarning :
                           .secondary
                )
            }

            Divider()

            HStack(spacing: 0) {
                vehicleInfoItem(icon: "fuelpump", value: "\(vehicle.fuelPercentage)%", label: "Fuel")
                Divider().frame(height: 30)
                vehicleInfoItem(icon: "speedometer", value: vehicle.formattedMileage, label: "Mileage")
                Divider().frame(height: 30)
                vehicleInfoItem(icon: "number", value: vehicle.licensePlate, label: "Plate")
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func vehicleInfoItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.primaryGreen)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(icon: "road.lanes", title: "Total Miles", value: String(format: "%.0f", vm.totalMiles))
            StatCard(icon: "truck.box", title: "Total Trips", value: "\(vm.totalTrips)")
        }
    }

    // MARK: - Upcoming Trips Section
    private var upcomingTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppTheme.sectionHeader("Upcoming")
                Spacer()
                NavigationLink("View All") {
                    TripListView(user: user)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryGreen)
            }

            ForEach(vm.upcomingTrips) { trip in
                NavigationLink {
                    TripDetailView(trip: trip, user: user)
                } label: {
                    upcomingTripRow(trip)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func upcomingTripRow(_ trip: Trip) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "truck.box.fill")
                .font(.body)
                .foregroundStyle(AppTheme.primaryGreen)
                .frame(width: 40, height: 40)
                .background(AppTheme.lightGreen)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.endLocation)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Text("ETA")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(trip.scheduledStartTime, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(trip.formattedDistance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if Calendar.current.isDateInToday(trip.scheduledStartTime) {
                StatusBadge(text: "Today", color: AppTheme.primaryGreen)
            } else {
                Text(trip.scheduledStartTime, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .cardStyle()
    }
}
