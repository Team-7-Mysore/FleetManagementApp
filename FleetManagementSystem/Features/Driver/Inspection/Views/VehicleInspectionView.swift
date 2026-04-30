import SwiftUI

// MARK: - Vehicle Inspection View
struct VehicleInspectionView: View {
    let user: User
    let trip: TripMap?
    
    @StateObject private var vm: InspectionViewModel
    @State private var showNewInspectionSheet = false
    @State private var overallNotes = ""
    @State private var showSubmissionConfirmation = false
    @State private var showReportIssue = false
    @State private var showSDVScanner = false
    @State private var showTripCompletionError = false
    @State private var inspectionSnapshot: Inspection?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter

    let defaultType: InspectionType

    init(user: User, trip: TripMap? = nil, defaultType: InspectionType = .preTrip) {
        self.user = user
        self.trip = trip
        self.defaultType = defaultType
        _vm = StateObject(wrappedValue: InspectionViewModel(user: user))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let tripId = trip?.id {
                     Button(action: { showSDVScanner = true }) {
                         HStack {
                             Image(systemName: "sparkles")
                             Text("Run SDV Diagnostics")
                         }
                         .font(.headline)
                         .foregroundColor(.white)
                         .padding()
                         .frame(maxWidth: .infinity)
                         .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                         .cornerRadius(12)
                     }
                     .padding(.bottom, 8)
                     .sheet(isPresented: $showSDVScanner) {
                         if let unwrappedTrip = trip {
                             SDVAutoScannerView(vehicleId: unwrappedTrip.vehicleId, inspectionType: defaultType) { reports in
                                 vm.autoPassAllItems()
                                 
                                 // If SDV diagnostics found issues, mark them as failed
                                 if !reports.isEmpty {
                                     for report in reports {
                                         if report.category == "mechanical" {
                                             vm.failCategory("Mechanical", reason: report.description)
                                         } else if report.category == "body damage" {
                                             vm.failCategory("Exterior", reason: report.description)
                                         } else if report.category == "electrical" {
                                             vm.failCategory("Safety", reason: report.description)
                                         }
                                     }
                                 }
                             }
                         }
                     }
                }
                
                currentInspectionContent
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("Vehicle Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if displayedInspection == nil {
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
        .alert(confirmationTitle, isPresented: $showSubmissionConfirmation) {
            Button(confirmationButtonTitle) {
                handleSubmitConfirmation()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
        .alert("Couldn’t End Trip", isPresented: $showTripCompletionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Trip could not be marked completed. Please try again.")
        }
        .sheet(isPresented: $showReportIssue) {
            reportIssueSheet
        }
        .onAppear {
            vm.loadDataAndAutoStart(for: trip, type: defaultType)
        }
        .onChange(of: showReportIssue) { _, isPresented in
            if !isPresented {
                inspectionSnapshot = nil
            }
        }
    }

    // MARK: - Extracted Sheet
    @ViewBuilder
    private var reportIssueSheet: some View {
        let vehicleToReport: Vehicle? = trip.map { trip in
            Vehicle(
                id: trip.vehicleId,
                name: trip.startLocation,
                registrationNumber: "",
                vehicleType: "unknown"
            )
        }

        ReportIssueView(
            user: user,
            vehicle: vehicleToReport,
            activeTripId: trip?.id,
            prefilledDescription: nil as String?,
            prefilledCategory: nil as String?,
            prefilledSeverity: nil as String?,
            showsCloseButton: true
        ) {
            handleReportSubmit()
        }
    }

    // MARK: - Extracted Logic
    private func handleReportSubmit() {
        if let trip {
            if isPostTripFlow {
                Task {
                    let didComplete = await vm.submitAndCompleteTrip(notes: overallNotes, trip: trip)
                    await MainActor.run {
                        if didComplete {
                            NotificationCenter.default.post(
                                name: .driverTripCompleted,
                                object: nil,
                                userInfo: ["tripId": trip.id]
                            )
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TripStatusChanged"),
                                object: nil
                            )
                            router.resetPath()
                        } else {
                            showTripCompletionError = true
                        }
                    }
                }
            } else {
                vm.submitInspection(notes: overallNotes)
                router.resetPath()
            }
        } else {
            vm.submitInspection(notes: overallNotes)
            dismiss()
        }
    }

    private var displayedInspection: Inspection? {
        vm.currentInspection ?? inspectionSnapshot
    }

    // MARK: - Current Inspection
    @ViewBuilder
    private var currentInspectionContent: some View {
        if let inspection = displayedInspection {
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundStyle(AppTheme.primaryGreen)
                        .font(.subheadline)
                    Text("Overall Notes")
                        .font(.subheadline.weight(.semibold))
                }
                TextEditor(text: $overallNotes)
                    .frame(height: 90)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
                    )
            }
            .padding(16)
            .cardStyle()
            .padding(.top, 4)

            // Action Button
            if vm.canSubmit {
                if inspection.failCount > 0 {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.statusDanger)
                            Text(blockingIssuesMessage(for: inspection.failCount))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.statusDanger)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.statusDanger.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button {
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
                    Button { showSubmissionConfirmation = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: primaryActionSymbol)
                            Text(primaryActionTitle)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
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
                HStack(spacing: 8) {
                    Text(item.status.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(itemColor(item.status))
                    Button {
                        vm.updateItem(itemId: item.id, status: .pending)
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
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

    private var isPostTripFlow: Bool {
        trip != nil && defaultType == .postTrip
    }

    private var primaryActionTitle: String {
        if isPostTripFlow { return "Submit Inspection" }
        return trip != nil ? "Start Trip" : "Submit Inspection"
    }

    private var primaryActionSymbol: String {
        if isPostTripFlow { return "checkmark.circle.fill" }
        return trip != nil ? "play.fill" : "checkmark.circle.fill"
    }

    private var confirmationTitle: String {
        isPostTripFlow ? "End Trip" : "Start Trip"
    }

    private var confirmationButtonTitle: String {
        isPostTripFlow ? "Submit Inspection" : "Start Trip"
    }

    private var confirmationMessage: String {
        if isPostTripFlow {
            return "Post-trip inspection passed. Submit and return to home screen?"
        }
        return "Inspection passed! Ready to start the trip?"
    }

    private func blockingIssuesMessage(for failCount: Int) -> String {
        if isPostTripFlow {
            return "\(failCount) issue\(failCount == 1 ? "" : "s") found. Resolve or report before closing the trip."
        }
        return "\(failCount) issue\(failCount == 1 ? "" : "s") found. Trip cannot start."
    }

    private func handleSubmitConfirmation() {
        if let trip {
            if isPostTripFlow {
                Task {
                    let didComplete = await vm.submitAndCompleteTrip(notes: overallNotes, trip: trip)
                    await MainActor.run {
                        if didComplete {
                            NotificationCenter.default.post(
                                name: .driverTripCompleted,
                                object: nil,
                                userInfo: ["tripId": trip.id]
                            )
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TripStatusChanged"),
                                object: nil
                            )
                            router.resetPath()
                        } else {
                            showTripCompletionError = true
                        }
                    }
                }
            } else {
                vm.submitAndStartTrip(notes: overallNotes, trip: trip)
                router.path = NavigationPath([AppRoute.activeTrip(trip)])
            }
        } else {
            vm.submitInspection(notes: overallNotes)
            dismiss()
        }
    }
}
