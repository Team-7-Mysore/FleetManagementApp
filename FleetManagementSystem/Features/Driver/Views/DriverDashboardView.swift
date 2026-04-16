import SwiftUI

struct DriverDashboardView: View {
    @StateObject private var viewModel = DriverDashboardViewModel()

    var body: some View {
        NavigationStack {
            DriverHomeView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadDashboard()
        }
        .environment(\.colorScheme, .light)
    }
}

struct DriverDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DriverDashboardView()
            .environmentObject(AppSessionStore())
    }
}

struct DriverHomeView: View {
    @EnvironmentObject private var sessionStore: AppSessionStore
    @ObservedObject var viewModel: DriverDashboardViewModel

    var body: some View {
        ZStack {
            DriverTheme.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topHeader

                    if viewModel.isLoading && viewModel.assignment == nil {
                        loadingCard
                    } else if let assignment = viewModel.assignment {
                        activeRouteCard(assignment)
                        assignedVehicleCard(assignment)
                        startInspectionButton
                        dashboardActions
                        upcomingTasksSection
                    } else if let errorMessage = viewModel.errorMessage {
                        ErrorStateCard(message: errorMessage) {
                            Task { await viewModel.loadDashboard() }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationBarHidden(true)
    }

    private var topHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.84, green: 0.95, blue: 0.88), Color(red: 0.68, green: 0.83, blue: 0.74)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Text(driverInitials)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(DriverTheme.primaryText)
                }
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text("DRIVER")
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(DriverTheme.accent)

                Text(driverName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(DriverTheme.primaryText)
                    .lineLimit(1)
            }

            Spacer()

            NavigationLink {
                DriverMessagesView(viewModel: viewModel)
            } label: {
                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DriverTheme.primaryText)
                    .frame(width: 42, height: 42)
                    .background(Color.white, in: Circle())
                    .shadow(color: DriverTheme.shadowColor, radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Button {
            } label: {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DriverTheme.primaryText)
                    .frame(width: 42, height: 42)
                    .background(Color.white, in: Circle())
                    .shadow(color: DriverTheme.shadowColor, radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Menu {
                Button("Sign Out", role: .destructive) {
                    sessionStore.signOut()
                }
            } label: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DriverTheme.accent.opacity(0.95), DriverTheme.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)
                    .shadow(color: DriverTheme.shadowColor, radius: 10, x: 0, y: 4)
            }
        }
        .padding(.top, 6)
    }

    private func activeRouteCard(_ assignment: DriverAssignment) -> some View {
        let activeTrip = currentTrip

        return NavigationLink {
            DriverTripsView(viewModel: viewModel)
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.72, green: 0.86, blue: 0.96),
                                Color(red: 0.93, green: 0.95, blue: 0.97),
                                Color.white
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topTrailing) {
                        RouteArtwork()
                            .opacity(0.72)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [Color.white.opacity(0), Color.white.opacity(0.88), Color.white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 160)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                        )
                    }
                    .shadow(color: DriverTheme.shadowColor, radius: 18, x: 0, y: 8)

                VStack(alignment: .leading, spacing: 18) {
                    BadgeView(title: "ACTIVE ROUTE", tone: .accent)
                        .padding(.top, 16)
                        .padding(.leading, 16)

                    Spacer(minLength: 82)

                    HStack(alignment: .bottom, spacing: 20) {
                        VStack(alignment: .leading, spacing: 16) {
                            RouteInfoBlock(
                                caption: "FROM",
                                value: assignment.startLocation,
                                icon: "circle.inset.filled"
                            )

                            RouteInfoBlock(
                                caption: "TO",
                                value: assignment.destination,
                                icon: "mappin.and.ellipse"
                            )
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(activeTrip?.distance.numericPortion ?? "142")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(DriverTheme.primaryText)
                            + Text(activeTrip?.distance.unitPortion ?? " mi")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(DriverTheme.secondaryText)

                            Text(activeTrip?.eta.shortETA ?? "2h 15m")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DriverTheme.secondaryText)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 270)
        }
        .buttonStyle(.plain)
    }

    private func assignedVehicleCard(_ assignment: DriverAssignment) -> some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Assigned Vehicle")
                            .font(.headline)
                            .foregroundStyle(DriverTheme.primaryText)

                        Text(assignment.vehicleName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(DriverTheme.primaryText)

                        Text(assignment.registrationNumber)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DriverTheme.secondaryText)
                    }

                    Spacer()

                    BadgeView(title: "On Duty", tone: .accent)
                }

                VStack(spacing: 12) {
                    DetailRow(icon: "map.fill", title: "Route", value: assignment.routeName)
                    DetailRow(icon: "clock.fill", title: "Shift", value: assignment.shiftWindow)
                    DetailRow(icon: "location.fill", title: "Start Location", value: assignment.startLocation)
                    DetailRow(icon: "flag.pattern.checkered", title: "Destination Info", value: assignment.destination)
                    DetailRow(icon: "shippingbox.fill", title: "Cargo", value: assignment.cargoSummary)
                }
            }
        }
    }

    private var startInspectionButton: some View {
        NavigationLink {
            DriverInspectionView(viewModel: viewModel)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checklist")
                    .font(.headline)
                Text("Start Inspection")
                    .font(.title3.weight(.bold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionButtonStyle())
    }

    private var dashboardActions: some View {
        HStack(spacing: 12) {
            NavigationLink {
                DriverTripsView(viewModel: viewModel)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Trip")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle(isSelected: true))

            NavigationLink {
                DriverTripsView(viewModel: viewModel)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "map")
                    Text("View Trips")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle(isSelected: false))
        }
    }

    private var upcomingTasksSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Upcoming Tasks")
                    .font(.headline)
                    .foregroundStyle(DriverTheme.primaryText)

                Spacer()

                NavigationLink {
                    DriverTripsView(viewModel: viewModel)
                } label: {
                    Text("View All")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DriverTheme.accent)
                }
            }

            ForEach(upcomingTasks) { task in
                TaskListItem(task: task)
            }
        }
    }

    private var loadingCard: some View {
        DashboardCard {
            VStack(spacing: 14) {
                ProgressView()
                    .tint(DriverTheme.accent)

                Text("Loading your route and trip details...")
                    .foregroundStyle(DriverTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private var currentTrip: DriverTrip? {
        viewModel.trips.first(where: { $0.id == viewModel.activeTripID }) ?? viewModel.trips.first
    }

    private var upcomingTasks: [UpcomingTask] {
        var tasks: [UpcomingTask] = []

        if let upcomingTrip = viewModel.trips.first(where: { $0.status == .upcoming }) {
            tasks.append(
                UpcomingTask(
                    icon: "truck.box.fill",
                    title: upcomingTrip.title,
                    subtitle: upcomingTrip.route,
                    eta: upcomingTrip.eta,
                    badge: "SOON"
                )
            )
        }

        if let fuelStat = viewModel.stats.first(where: { $0.title.localizedCaseInsensitiveContains("fuel") }) {
            tasks.append(
                UpcomingTask(
                    icon: "fuelpump.fill",
                    title: "Fuel Stop",
                    subtitle: fuelStat.detail,
                    eta: fuelStat.value,
                    badge: "CHECK"
                )
            )
        }

        if tasks.isEmpty, let nextMessage = viewModel.messages.first {
            tasks.append(
                UpcomingTask(
                    icon: "message.fill",
                    title: nextMessage.subject,
                    subtitle: nextMessage.preview,
                    eta: nextMessage.time,
                    badge: "NEW"
                )
            )
        }

        return tasks
    }

    private var driverName: String {
        if case .signedIn(let session) = sessionStore.state {
            return session.user.fullName
        }

        return "Aarav Kulkarni"
    }

    private var driverInitials: String {
        driverName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
    }
}

struct DriverTripsView: View {
    @ObservedObject var viewModel: DriverDashboardViewModel

    var body: some View {
        ZStack {
            DriverTheme.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(viewModel.trips) { trip in
                        DashboardCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(trip.title)
                                            .font(.headline)
                                            .foregroundStyle(DriverTheme.primaryText)

                                        Text(trip.route)
                                            .font(.subheadline)
                                            .foregroundStyle(DriverTheme.secondaryText)
                                    }

                                    Spacer()

                                    BadgeView(title: trip.status.displayName, tone: trip.id == viewModel.activeTripID ? .accent : .neutral)
                                }

                                HStack {
                                    DriverDetailBadge(icon: "calendar", text: trip.schedule)
                                    DriverDetailBadge(icon: "arrow.triangle.swap", text: trip.distance)
                                }

                                HStack {
                                    DriverDetailBadge(icon: "location.fill", text: trip.eta)

                                    Spacer()

                                    Button(trip.id == viewModel.activeTripID ? "In Progress" : "Start Trip") {
                                        viewModel.startTrip(trip)
                                    }
                                    .buttonStyle(SecondaryActionButtonStyle(isSelected: trip.id == viewModel.activeTripID))
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DriverInspectionView: View {
    @ObservedObject var viewModel: DriverDashboardViewModel

    var body: some View {
        ZStack {
            DriverTheme.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    DashboardCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Pre/Post Trip Checklist")
                                .font(.headline)
                                .foregroundStyle(DriverTheme.primaryText)

                            Text("Mark each item as you inspect the vehicle. These updates can later feed maintenance tickets.")
                                .font(.footnote)
                                .foregroundStyle(DriverTheme.secondaryText)
                        }
                    }

                    ForEach(viewModel.inspectionItems) { item in
                        Button {
                            viewModel.toggleInspectionItem(item)
                        } label: {
                            DashboardCard {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(item.isCompleted ? DriverTheme.accent : DriverTheme.subtleFill)
                                            .frame(width: 30, height: 30)

                                        Image(systemName: item.isCompleted ? "checkmark" : "circle")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(item.isCompleted ? .white : DriverTheme.secondaryText)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundStyle(DriverTheme.primaryText)

                                        Text(item.detail)
                                            .font(.footnote)
                                            .foregroundStyle(DriverTheme.secondaryText)
                                    }

                                    Spacer()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Inspection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DriverMessagesView: View {
    @EnvironmentObject private var sessionStore: AppSessionStore
    @ObservedObject var viewModel: DriverDashboardViewModel

    var body: some View {
        ZStack {
            DriverTheme.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    DashboardCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Messages & Support")
                                .font(.headline)
                                .foregroundStyle(DriverTheme.primaryText)

                            Text("Drivers can receive dispatch changes, maintenance confirmations, and route notes here.")
                                .font(.footnote)
                                .foregroundStyle(DriverTheme.secondaryText)
                        }
                    }

                    ForEach(viewModel.messages) { message in
                        DashboardCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(message.sender)
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(DriverTheme.accent)

                                        Text(message.subject)
                                            .font(.headline)
                                            .foregroundStyle(DriverTheme.primaryText)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 6) {
                                        BadgeView(title: message.priority.displayName, tone: message.priority == .high ? .accent : .neutral)
                                        Text(message.time)
                                            .font(.footnote)
                                            .foregroundStyle(DriverTheme.secondaryText)
                                    }
                                }

                                Text(message.preview)
                                    .font(.subheadline)
                                    .foregroundStyle(DriverTheme.secondaryText)
                            }
                        }
                    }

                    Button("Sign Out") {
                        sessionStore.signOut()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
                .padding(20)
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DashboardCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DriverTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: DriverTheme.shadowColor, radius: 18, x: 0, y: 6)
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DriverTheme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DriverTheme.secondaryText)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(DriverTheme.primaryText)
            }

            Spacer()
        }
    }
}

private struct RouteInfoBlock: View {
    let caption: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DriverTheme.accent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(DriverTheme.secondaryText)

                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DriverTheme.primaryText)
                    .lineLimit(2)
            }
        }
    }
}

private struct RouteArtwork: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.clear,
                    Color(red: 0.81, green: 0.88, blue: 0.92).opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Path { path in
                path.move(to: CGPoint(x: 20, y: 42))
                path.addCurve(
                    to: CGPoint(x: 280, y: 84),
                    control1: CGPoint(x: 100, y: 12),
                    control2: CGPoint(x: 190, y: 136)
                )
            }
            .stroke(Color.white.opacity(0.52), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 10]))

            Path { path in
                path.move(to: CGPoint(x: 68, y: 18))
                path.addCurve(
                    to: CGPoint(x: 250, y: 54),
                    control1: CGPoint(x: 114, y: 70),
                    control2: CGPoint(x: 190, y: 2)
                )
            }
            .stroke(DriverTheme.accent.opacity(0.25), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            Circle()
                .fill(DriverTheme.accent.opacity(0.95))
                .frame(width: 10, height: 10)
                .offset(x: -90, y: -25)

            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 10, height: 10)
                .offset(x: 95, y: 12)
        }
    }
}

private struct DriverDetailBadge: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.medium))
            .foregroundStyle(DriverTheme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(DriverTheme.subtleFill, in: Capsule())
    }
}

private struct TaskListItem: View {
    let task: UpcomingTask

    var body: some View {
        DashboardCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(DriverTheme.subtleGreen)
                        .frame(width: 42, height: 42)

                    Image(systemName: task.icon)
                        .foregroundStyle(DriverTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(DriverTheme.primaryText)

                    Text(task.subtitle)
                        .font(.footnote)
                        .foregroundStyle(DriverTheme.secondaryText)
                        .lineLimit(2)

                    Text(task.eta)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DriverTheme.secondaryText)
                }

                Spacer()

                BadgeView(title: task.badge, tone: .lightAccent)
            }
        }
    }
}

private struct BadgeView: View {
    enum Tone {
        case accent
        case neutral
        case lightAccent
    }

    let title: String
    let tone: Tone

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor, in: Capsule())
    }

    private var backgroundColor: Color {
        switch tone {
        case .accent:
            return DriverTheme.accent
        case .neutral:
            return DriverTheme.subtleFill
        case .lightAccent:
            return DriverTheme.subtleGreen
        }
    }

    private var textColor: Color {
        switch tone {
        case .accent:
            return .white
        case .neutral:
            return DriverTheme.secondaryText
        case .lightAccent:
            return DriverTheme.accent
        }
    }
}

private struct ErrorStateCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        DashboardCard {
            VStack(spacing: 14) {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(DriverTheme.primaryText)
                    .multilineTextAlignment(.center)

                Button("Retry", action: retry)
                    .buttonStyle(PrimaryActionButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct UpcomingTask: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let eta: String
    let badge: String
}

private extension String {
    var numericPortion: String {
        let digits = filter { $0.isNumber }
        return digits.isEmpty ? self : digits
    }

    var unitPortion: String {
        let trimmed = replacingOccurrences(of: numericPortion, with: "")
            .replacingOccurrences(of: "remaining", with: "")
            .replacingOccurrences(of: "ETA", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmed.isEmpty ? "" : " \(trimmed)"
    }

    var shortETA: String {
        replacingOccurrences(of: "ETA", with: "")
            .replacingOccurrences(of: "remaining", with: "left")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
