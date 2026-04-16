import SwiftUI

struct TripsListView: View {
    @State private var showCreateTrip = false
    @State private var showAllTrips = false
    @StateObject private var vm = TripListViewModel()

    var body: some View {
        NavigationView {
        ZStack {
            // Background
            Color(hex: "F5F5FA")
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Header
                headerSection

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {

                        // MARK: - Search Bar
                        searchBar

                        // MARK: - Active Trips Overview Card
                        activeTripsCard

                        // MARK: - Ongoing Trips
                        ongoingTripsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }

            // MARK: - FAB
            floatingActionButton
        }
        .onAppear {
            Task { await vm.fetchTrips() }
        }
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView()
        }
        .navigationBarHidden(true)
        .background(
            NavigationLink(
                destination: AllTripsView(),
                isActive: $showAllTrips
            ) { EmptyView() }
        )
        } // NavigationView
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .bottom) {
            Text("Admin")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "1A1A2E"))
            
            Spacer()
            
            HStack(spacing: 16) {
                // Calendar icon
                headerIconButton(systemName: "calendar")
                
                // Notification bell
                headerIconButton(systemName: "bell")
            }
            .padding(.bottom, 4) // Align icons slightly lower to match large title baseline
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(Color.white)
    }

    private func headerIconButton(systemName: String) -> some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Color(hex: "1A1A2E"))
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "9CA3AF"))

            TextField("Search trips, vehicles, drivers", text: $vm.searchText)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "1A1A2E"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.top, 8)
    }

    // MARK: - Active Trips Card
    private var activeTripsCard: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background gradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "7C4DFF"),
                            Color(hex: "6C63FF"),
                            Color(hex: "9575FF")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Decorative circles for depth
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 140, height: 140)
                .offset(x: 40, y: -20)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 100, height: 100)
                .offset(x: -30, y: 50)

            // Truck icon watermark
            Image(systemName: "truck.box.fill")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.12))
                .offset(x: -10, y: -10)

            // Content
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("OVERVIEW")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .tracking(1.5)

                    Spacer()

                    // Live Tracking badge
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(hex: "00E676"))
                            .frame(width: 7, height: 7)

                        Text("LIVE TRACKING")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Capsule())
                }

                Text("Active\nTrips")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .lineSpacing(2)

                Spacer().frame(height: 4)

                Text("\(vm.activeTripCount) Active Trips")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Text("Currently in transit across all regions")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.75))

                Spacer().frame(height: 4)

                // Capacity bar
                HStack {
                    Text("System Capacity")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Text("\(vm.capacityPercent)%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.25))
                            .frame(height: 6)

                        Capsule()
                            .fill(Color.white)
                            .frame(
                                width: geo.size.width * CGFloat(vm.capacityPercent) / 100.0,
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
            }
            .padding(20)
        }
        .frame(height: 260)
    }

    // MARK: - Ongoing Trips
    private var ongoingTripsSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Ongoing Trips")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A2E"))

                Spacer()

                Button(action: { showAllTrips = true }) {
                    Text("View All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "6C63FF"))
                }
            }

            if vm.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading trips...")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if vm.filteredTrips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "D1D5DB"))

                    Text("No trips found")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "6B7280"))

                    Text("Trips will appear here once created")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(vm.filteredTrips) { trip in
                        TripCardView(trip: trip)
                    }
                }
            }
        }
    }

    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { showCreateTrip = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "7C4DFF"), Color(hex: "6C63FF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color(hex: "6C63FF").opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
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

#Preview {
    TripsListView()
}
