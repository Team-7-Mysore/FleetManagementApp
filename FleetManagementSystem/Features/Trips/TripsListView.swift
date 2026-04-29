import SwiftUI
import Supabase

struct TripsListView: View {

    let profile: UserProfile?
    let onSignOut: () async -> Void
    @State private var navigateToNotifications = false

    @StateObject private var vm = TripListViewModel()
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"
    @State private var showingProfile = false
    @State private var selectedWorkOrder: WorkOrder? = nil

    init(profile: UserProfile? = nil, onSignOut: @escaping () async -> Void = {}) {
        self.profile = profile
        self.onSignOut = onSignOut
    }

    // MARK: - Computed Properties for Separation
    private var pendingApprovals: [WorkOrder] {
        vm.vehiclesInMaintenance.filter { $0.status == .pending }
    }

    private var activeMaintenance: [WorkOrder] {
        vm.vehiclesInMaintenance.filter { $0.status == .inProgress }
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

                        // 👇 NEW: Pending Approvals Section
                        if !pendingApprovals.isEmpty {
                            pendingApprovalsSection
                        }

                        // Vehicles in Maintenance Section (Now only shows .inProgress)
                        if !activeMaintenance.isEmpty {
                            maintenanceSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Dashboard")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            navigateToNotifications = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color.black)

                                if vm.unreadNotificationCount > 0 {
                                    Text("\(vm.unreadNotificationCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(minWidth: 16, minHeight: 16)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 6, y: -2)
                                }
                            }
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
                    if vm.trips.isEmpty {
                        await vm.fetchTrips()
                    }
                }
                .refreshable {
                    await vm.fetchTrips()
                }
                .sheet(isPresented: $showingProfile) {
                    FleetManagerProfileView(profile: profile, onSignOut: onSignOut)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .environment(\.locale, .init(identifier: selectedLanguage))
                }
                .navigationDestination(isPresented: $navigateToNotifications) {
                    FleetManagerNotificationsView(userId: profile?.userId)
                }
                .sheet(item: $selectedWorkOrder) { workOrder in
                    NavigationStack {
                        // This already has manager approval mode enabled!
                        WorkOrderDetailView(workOrder: workOrder, isManagerApprovalMode: true)
                    }
                }

                floatingActionButton
            }
        }
    }

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
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                ForEach(Array(vm.filteredTrips.prefix(2))) { trip in
                    EnhancedTripCard(trip: trip)
                }
            }
        }
    }

    // MARK: - NEW: Pending Approvals Section
    private var pendingApprovalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pending Approvals")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink("View All", destination: AllPendingApprovalsView())
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.TechBlue)
            }

            ForEach(Array(pendingApprovals.prefix(3))) { workOrder in
                PendingApprovalCard(workOrder: workOrder) {
                    Task { await vm.approveWorkOrder(workOrder) }
                } onDecline: {
                    Task { await vm.declineWorkOrder(workOrder) }
                } onTap: {
                    selectedWorkOrder = workOrder
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

                NavigationLink("View All", destination: AllMaintenanceView())
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.TechBlue)
            }

            // 👇 Now uses activeMaintenance to exclude the pending ones shown above
            ForEach(Array(activeMaintenance.prefix(3))) { workOrder in
                Button(action: {
                    selectedWorkOrder = workOrder
                }) {
                    MaintenanceVehicleCard(workOrder: workOrder)
                }
                .buttonStyle(.plain)
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
        NavigationLink(destination: CreateTripView(fleetManagerId: profile?.userId)) {
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
        NavigationLink(destination: FleetManagerTripDetailView(trip: trip)) {
            VStack(alignment: .leading, spacing: 8) {
                // Top row - Route name and status badge
                HStack {
                    Text(trip.tripNameText)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)

                    Spacer()

                    statusBadge
                }

                // Bottom row - Route details
                HStack(spacing: 6) {
                    Text(trip.originText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .layoutPriority(1)

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 2)

                    Text(trip.destinationText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        Text(trip.normalisedStatus.displayTitle)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch trip.normalisedStatus {
        case .inTransit:
            return Color.orange
        case .inProgress:
            return Color.green
        case .scheduled:
            return Color.blue
        case .completed:
            return Color.green
        case .cancelled:
            return Color.red
        default:
            return Color.gray
        }
    }
}


// MARK: - Pending Approval Card (tap to view details)
// Swipe actions (approve/decline) are applied at the List row level in AllPendingApprovalsView.
// The dashboard uses ScrollView so swipe is not available there — use "View All" to access swipe.
struct PendingApprovalCard: View {
    let workOrder: WorkOrder
    let onApprove: () -> Void
    let onDecline: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(workOrder.vehicle?.vehicleName ?? workOrder.vehicle?.numberPlate ?? "Fleet Vehicle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)

                    Text(workOrder.issueTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(workOrder.priority.rawValue)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(priorityColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(priorityColor.opacity(0.12))
                            .clipShape(Capsule())

                        if let plate = workOrder.vehicle?.numberPlate {
                            Text(plate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.orange.opacity(0.08), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var priorityColor: Color {
        switch workOrder.priority {
        case .urgent: return .red
        case .high:   return .orange
        case .medium: return .yellow
        case .low:    return .green
        }
    }
}

// MARK: - Maintenance Vehicle Card
struct MaintenanceVehicleCard: View {

    let workOrder: WorkOrder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row - Vehicle name and status badge
            HStack {
                Text(workOrder.vehicle?.vehicleName ?? workOrder.vehicle?.numberPlate ?? "Fleet Vehicle")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.primary)

                Spacer()

                statusBadge
            }

            // Bottom row - Issue title
            Text(workOrder.issueTitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var statusBadge: some View {
        Text(workOrder.status.rawValue)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch workOrder.status {
        case .pending:
            return Color.orange
        case .inProgress:
            return Color.blue
        case .completed:
            return Color.green
        case .cancelled:
            return Color.red
        }
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
