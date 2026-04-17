import SwiftUI

// MARK: - Vehicle Inspection View
struct VehicleInspectionView: View {
    let user: User
    let trip: Trip?
    @StateObject private var vm: InspectionViewModel
    @State private var showNewInspectionSheet = false
    @State private var overallNotes = ""
    @State private var showStartTripConfirmation = false
    @State private var showReportIssue = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter

    init(user: User, trip: Trip? = nil) {
        self.user = user
        self.trip = trip
        _vm = StateObject(wrappedValue: InspectionViewModel(user: user))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Tab", selection: $vm.selectedTab) {
                ForEach(InspectionViewModel.InspectionTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    switch vm.selectedTab {
                    case .current:
                        currentInspectionContent
                    case .history:
                        historyContent
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("Vehicle Inspection")
        .toolbar {
            if vm.selectedTab == .current && vm.currentInspection == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewInspectionSheet = true } label: {
                        Image(systemName: "plus")
                    }
                    .tint(AppTheme.primaryGreen)
                }
            }
        }
        .confirmationDialog("New Inspection", isPresented: $showNewInspectionSheet) {
            Button("Pre-Trip Inspection") {
                vm.startNewInspection(type: .preTrip)
            }
            Button("Post-Trip Inspection") {
                vm.startNewInspection(type: .postTrip)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Start Trip", isPresented: $showStartTripConfirmation) {
            Button("Start Trip") {
                if let trip {
                    vm.submitAndStartTrip(notes: overallNotes, trip: trip)
                    // Push Active Trip, replaces the stack so back goes to Driver Dashboard root
                    router.path = NavigationPath([AppRoute.activeTrip(trip)])
                } else {
                    vm.submitInspection(notes: overallNotes)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Inspection passed! Ready to start the trip?")
        }
        .sheet(isPresented: $showReportIssue) {
            ReportIssueView(user: user, vehicle: VehicleService.shared.assignedVehicle(forDriver: user.id))
        }
        .onAppear { vm.loadData() }
    }

    // MARK: - Current Inspection
    @ViewBuilder
    private var currentInspectionContent: some View {
        if let inspection = vm.currentInspection {
            // Progress header
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(inspection.type.rawValue) Inspection")
                            .font(.headline)
                        Text(inspection.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    progressCircle(inspection)
                }

                // Completion bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppTheme.primaryGreen)
                            .frame(width: geo.size.width * inspection.completionPercentage, height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Label("\(inspection.passCount) Pass", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primaryGreen)
                    Spacer()
                    if inspection.failCount > 0 {
                        Label("\(inspection.failCount) Fail", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.statusDanger)
                    }
                    Spacer()
                    Label("\(inspection.pendingCount) Pending", systemImage: "circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .cardStyle()

            // Checklist items grouped by category
            let grouped = Dictionary(grouping: inspection.items, by: \.category)
            ForEach(Array(grouped.keys.sorted()), id: \.self) { category in
                VStack(alignment: .leading, spacing: 10) {
                    AppTheme.sectionHeader(category)

                    ForEach(grouped[category] ?? []) { item in
                        inspectionItemRow(item)
                    }
                }
            }

            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Overall Notes")
                    .font(.subheadline.weight(.semibold))
                TextEditor(text: $overallNotes)
                    .frame(height: 80)
                    .padding(8)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.top, 4)

            // Action Button — depends on inspection results
            if vm.canSubmit {
                if let inspection = vm.currentInspection, inspection.failCount > 0 {
                    // Has failures → Report Issue (safety first)
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.statusDanger)
                            Text("\(inspection.failCount) issue\(inspection.failCount == 1 ? "" : "s") found. Trip cannot start.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.statusDanger)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.statusDanger.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button {
                            vm.submitInspection(notes: overallNotes)
                            showReportIssue = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                Text("Report Issue")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(AppTheme.statusDanger)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                        }
                    }
                } else {
                    // All clear → Start Trip
                    Button { showStartTripConfirmation = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text(trip != nil ? "Start Trip" : "Submit Inspection")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                // Not all items checked yet
                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checklist")
                        Text("Complete All Items")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(true)
                .opacity(0.5)
            }

        } else {
            EmptyStateView(
                icon: "checklist",
                title: "No Active Inspection",
                message: "Start a new pre-trip or post-trip inspection.",
                actionTitle: "New Inspection",
                action: { showNewInspectionSheet = true }
            )
            .padding(.top, 40)
        }
    }

    // MARK: - Inspection Item Row
    private func inspectionItemRow(_ item: InspectionItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.systemImage)
                .font(.title3)
                .foregroundStyle(itemColor(item.status))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.status == .pending {
                HStack(spacing: 8) {
                    Button {
                        vm.updateItem(itemId: item.id, status: .pass)
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.primaryGreen)
                            .clipShape(Circle())
                    }

                    Button {
                        vm.updateItem(itemId: item.id, status: .fail)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.statusDanger)
                            .clipShape(Circle())
                    }
                }
            } else {
                Text(item.status.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(itemColor(item.status))
            }
        }
        .padding(14)
        .cardStyle()
    }

    private func itemColor(_ status: InspectionItemStatus) -> Color {
        switch status {
        case .pass:    return AppTheme.primaryGreen
        case .fail:    return AppTheme.statusDanger
        case .pending: return .secondary
        }
    }

    private func progressCircle(_ inspection: Inspection) -> some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 4)
                .frame(width: 50, height: 50)
            Circle()
                .trim(from: 0, to: inspection.completionPercentage)
                .stroke(AppTheme.primaryGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
            Text("\(Int(inspection.completionPercentage * 100))%")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primaryGreen)
        }
    }

    // MARK: - History
    @ViewBuilder
    private var historyContent: some View {
        if vm.history.isEmpty {
            EmptyStateView(
                icon: "clock.arrow.circlepath",
                title: "No History",
                message: "Completed inspections will appear here."
            )
            .padding(.top, 40)
        } else {
            ForEach(vm.history) { inspection in
                historyCard(inspection)
            }
        }
    }

    private func historyCard(_ inspection: Inspection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(inspection.type.rawValue, systemImage: inspection.type.systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusBadge(
                    text: inspection.overallStatus,
                    color: inspection.failCount > 0 ? AppTheme.statusDanger : AppTheme.primaryGreen
                )
            }

            HStack(spacing: 16) {
                Label("\(inspection.passCount) Pass", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.primaryGreen)
                if inspection.failCount > 0 {
                    Label("\(inspection.failCount) Fail", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(AppTheme.statusDanger)
                }
                Spacer()
                Text(inspection.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !inspection.overallNotes.isEmpty {
                Text(inspection.overallNotes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .cardStyle()
    }
}
