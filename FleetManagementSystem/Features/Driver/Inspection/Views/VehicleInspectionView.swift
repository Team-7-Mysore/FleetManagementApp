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
            }
            .padding(18)
            .cardStyle()
        } else {
            EmptyStateView(
                icon: "checklist",
                title: "No Active Inspection",
                message: "Start a new inspection.",
                actionTitle: "New Inspection",
                action: { showNewInspectionSheet = true }
            )
            .padding(.top, 40)
        }
    }

    private func progressCircle(_ inspection: Inspection) -> some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 4)
            Circle()
                .trim(from: 0, to: inspection.completionPercentage)
                .stroke(AppTheme.primaryGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 50, height: 50)
    }

    private var isPostTripFlow: Bool {
        trip != nil && defaultType == .postTrip
    }

    private var confirmationTitle: String {
        isPostTripFlow ? "End Trip" : "Start Trip"
    }

    private var confirmationButtonTitle: String {
        isPostTripFlow ? "Submit Inspection" : "Start Trip"
    }

    private var confirmationMessage: String {
        isPostTripFlow
        ? "Submit and return to home?"
        : "Ready to start the trip?"
    }

    private func handleSubmitConfirmation() {
        vm.submitInspection(notes: overallNotes)
        dismiss()
    }
}
