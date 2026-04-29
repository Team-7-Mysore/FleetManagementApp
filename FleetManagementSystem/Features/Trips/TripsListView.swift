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

    // State to handle the "Awaiting Approval" focus filter
    @State private var isShowingOnlyApprovals = false

    init(profile: UserProfile? = nil, onSignOut: @escaping () async -> Void = {}) {
        self.profile = profile
        self.onSignOut = onSignOut
    }

    private var pendingApprovals: [WorkOrder] {
        vm.vehiclesInMaintenance.filter { $0.status == .pending }
    }

    var body: some View {
        NavigationStack {
            List {
                // 1. Fleet Overview Section
                Section {
                    fleetOverviewSection
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                .opacity(isShowingOnlyApprovals ? 0.4 : 1.0)

                // 2. Ongoing Trips Section
                Section(header: sectionHeader(title: "Ongoing Trips", destination: AnyView(AllTripsView()))) {
                    ongoingTripsSection
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16))
                .opacity(isShowingOnlyApprovals ? 0.4 : 1.0)

                // 3. Vehicles in Maintenance (Combined Section with Focus Logic)
                maintenanceFocusSection
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    notificationToolbarButton
                    profileToolbarButton
                }
            }
            .task { if vm.trips.isEmpty { await vm.fetchTrips() } }
            .refreshable { await vm.fetchTrips() }
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
                    WorkOrderDetailView(workOrder: workOrder, isManagerApprovalMode: true)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                floatingActionButton
            }
        }
    }

    // MARK: - Extracted Maintenance Section

    private var maintenanceFocusSection: some View {
        Section(header: maintenanceHeader) {
            ForEach(vm.vehiclesInMaintenance) { workOrder in
                let isPending = workOrder.status == .pending

                MaintenanceVehicleCard(workOrder: workOrder)
                    // Focus Visuals
                    .opacity(!isShowingOnlyApprovals || isPending ? 1.0 : 0.3)
                    .scaleEffect(isShowingOnlyApprovals && isPending ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isShowingOnlyApprovals)
                    .onTapGesture {
                        selectedWorkOrder = workOrder
                    }
                    // Swipe logic: Enabled ONLY for pending items
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if isPending {
                            Button {
                                Task { await vm.declineWorkOrder(workOrder) }
                            } label: {
                                Label("Decline", systemImage: "xmark")
                            }
                            .tint(.red)

                            Button {
                                Task { await vm.approveWorkOrder(workOrder) }
                            } label: {
                                Label("Approve", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
            }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 10, trailing: 16))
    }

    private var maintenanceHeader: some View {
        HStack {
            Text("Vehicles in Maintenance")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
                .textCase(nil)

            Spacer()

            if !pendingApprovals.isEmpty {
                Button(action: {
                    withAnimation { isShowingOnlyApprovals.toggle() }
                }) {
                    HStack(spacing: 6) {
                        Text("\(pendingApprovals.count) Awaiting Approval")
                        if isShowingOnlyApprovals {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isShowingOnlyApprovals ? Color.orange : Color.orange.opacity(0.15))
                    .foregroundColor(isShowingOnlyApprovals ? .white : .orange)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helper Views

    private func sectionHeader(title: String, destination: AnyView) -> some View {
        HStack {
            Text(title).font(.title3.weight(.semibold)).foregroundColor(.primary).textCase(nil)
            Spacer()
            NavigationLink(destination: destination) {
                HStack(spacing: 4) {
                    Text("View All")
                    Image(systemName: "chevron.right").font(.caption)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.TechBlue)
            }
        }
        .padding(.vertical, 8)
    }

    private var fleetOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fleet Overview").font(.title3.weight(.semibold)).foregroundColor(.primary)
            HStack(spacing: 12) {
                overviewCard(title: "Available Drivers", value: "\(vm.availableDriverCount)", icon: "person.2.fill", color: Color(hex: "#4A90E2"))
                overviewCard(title: "Available Vehicles", value: "\(vm.availableVehicleCount)", icon: "car.2.fill", color: Color(hex: "#50C878"))
            }
        }
    }

    private func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
                Text(title).font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.primary).frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity).padding(12).background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var ongoingTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            } else if vm.filteredTrips.isEmpty {
                emptyStateView(icon: "shippingbox", title: "No Ongoing Trips", subtitle: "Active trips will appear here")
            } else {
                ForEach(Array(vm.filteredTrips.prefix(2))) { trip in
                    EnhancedTripCard(trip: trip)
                }
            }
        }
    }

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 48)).foregroundColor(.secondary)
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var notificationToolbarButton: some View {
        Button { navigateToNotifications = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell").font(.system(size: 18, weight: .medium)).foregroundColor(.black)
                if vm.unreadNotificationCount > 0 {
                    Text("\(vm.unreadNotificationCount)").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                        .frame(minWidth: 16, minHeight: 16).background(Color.red).clipShape(Circle()).offset(x: 6, y: -2)
                }
            }
        }
    }

    private var profileToolbarButton: some View {
        Button { showingProfile = true } label: {
            Image(systemName: "person.circle.fill").font(.title3).foregroundColor(.TechBlue)
        }
    }

    private var floatingActionButton: some View {
        NavigationLink(destination: CreateTripView(fleetManagerId: profile?.userId)) {
            Image(systemName: "plus").font(.title2.weight(.bold)).foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(LinearGradient(colors: [Color.TechBlue, Color.TechBlue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Circle())
                .shadow(color: Color.TechBlue.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, 20).padding(.bottom, 24)
    }
}

// MARK: - Enhanced Trip Card (Cleaned)
struct EnhancedTripCard: View {
    let trip: Trip
    var body: some View {
        ZStack {
            NavigationLink(destination: FleetManagerTripDetailView(trip: trip)) {
                EmptyView()
            }
            .opacity(0)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(trip.tripNameText).font(.headline.weight(.bold)).foregroundColor(.primary)
                    Spacer()
                    statusBadge
                }
                HStack(spacing: 6) {
                    Text(trip.originText).frame(maxWidth: .infinity, alignment: .leading).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                    Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
                    Text(trip.destinationText).frame(maxWidth: .infinity, alignment: .leading).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .padding(14).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
    }

    private var statusBadge: some View {
        Text(trip.normalisedStatus.displayTitle).font(.caption2.weight(.bold)).foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 5).background(statusColor).clipShape(Capsule())
    }

    private var statusColor: Color {
        switch trip.normalisedStatus {
        case .inTransit: return Color(hex: "#F59E0B")
        case .inProgress: return Color(hex: "#3B82F6")
        case .scheduled: return Color(hex: "#8B5CF6")
        case .completed: return Color(hex: "#10B981")
        case .cancelled: return Color(hex: "#EF4444")
        default: return Color(.systemGray)
        }
    }
}

// MARK: - Maintenance Vehicle Card (Title/Subtitle Style)
struct MaintenanceVehicleCard: View {
    let workOrder: WorkOrder
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(workOrder.status == .pending ? Color.orange.opacity(0.12) : Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(workOrder.status == .pending ? .orange : .blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(workOrder.vehicle?.vehicleName ?? workOrder.vehicle?.numberPlate ?? "Fleet Vehicle")
                    .font(.subheadline.weight(.semibold)).foregroundColor(.primary)
                Text(workOrder.issueTitle).font(.caption).foregroundColor(.secondary).lineLimit(2)
            }

            Spacer()

            HStack(spacing: 8) {
                if workOrder.status == .pending {
                    Text(workOrder.priority.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12)).clipShape(Capsule())
                } else {
                    Text(workOrder.status.rawValue.capitalized)
                        .font(.caption2.weight(.bold)).foregroundColor(.blue)
                }
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(14).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
