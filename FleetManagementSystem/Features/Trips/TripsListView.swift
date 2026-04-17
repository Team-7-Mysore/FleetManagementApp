import SwiftUI

struct TripsListView: View {
    @State private var showCreateTrip = false
    @StateObject private var vm = TripListViewModel()

    private var displayedTrips: [Trip] {
        let trimmedSearch = vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSearch.isEmpty ? Array(vm.filteredTrips.prefix(4)) : vm.filteredTrips
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    Section {
                        overviewCard
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    Section {
                        if vm.isLoading {
                            loadingState
                        } else if vm.filteredTrips.isEmpty {
                            emptyState
                        } else {
                            ForEach(displayedTrips) { trip in
                                TripCardView(trip: trip)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    } header: {
                        ongoingTripsHeader
                    } footer: {
                        if !vm.isLoading && !vm.filteredTrips.isEmpty {
                            Text("Pull down to refresh the latest trip status.")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Trips")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        toolbarIconButton(systemName: "calendar")
                        toolbarIconButton(systemName: "bell")
                    }
                }
                .task {
                    guard vm.trips.isEmpty else { return }
                    await vm.fetchTrips()
                }
                .refreshable {
                    await vm.fetchTrips()
                }
                .sheet(isPresented: $showCreateTrip) {
                    CreateTripView()
                }

                floatingActionButton
            }
        }
    }

    private var ongoingTripsHeader: some View {
        HStack {
            Text("Ongoing Trips")
            Spacer()
            NavigationLink("View All", destination: AllTripsView())
                .font(.subheadline.weight(.semibold))
                .textCase(nil)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trips Overview")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Monitor active deliveries and use the floating action button to create a trip.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "truck.box")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 12) {
                metricTile(
                    title: "Active",
                    value: "\(vm.activeTripCount)",
                    systemImage: "point.3.filled.connected.trianglepath.dotted"
                )

                metricTile(
                    title: "Capacity",
                    value: "\(vm.capacityPercent)%",
                    systemImage: "chart.bar.fill"
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Fleet Activity")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(vm.capacityPercent)%")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: Double(vm.capacityPercent), total: 100)
                    .tint(.primaryBrown)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func toolbarIconButton(systemName: String) -> some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
        }
    }

    private func metricTile(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Loading ongoing trips…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Ongoing Trips",
            systemImage: "truck.box",
            description: Text("Trips that are scheduled or currently moving will appear here.")
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var floatingActionButton: some View {
        Button {
            showCreateTrip = true
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.primaryBrown, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
        .accessibilityLabel("Add Trip")
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
