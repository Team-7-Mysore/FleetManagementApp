import SwiftUI
import Combine


// MARK: - Local Issue Entry Model
struct IssueEntry: Identifiable {
    let id = UUID()
    var category: String = "Mechanical"
    var severity: String = "Medium"
    var description: String = ""
}

// MARK: - Report Issue View
struct ReportIssueView: View {
    let user: User
    let vehicle: Vehicle?
    let prefilledDescription: String?
    let prefilledCategory: String?
    let prefilledSeverity: String?

    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm: ReportIssueViewModel
    @State private var issues: [IssueEntry]

    init(
        user: User,
        vehicle: Vehicle?,
        activeTripId: UUID? = nil,
        prefilledDescription: String? = nil,
        prefilledCategory: String? = nil,
        prefilledSeverity: String? = nil
    ) {
        self.user = user
        self.vehicle = vehicle
        self.prefilledDescription = prefilledDescription
        self.prefilledCategory = prefilledCategory
        self.prefilledSeverity = prefilledSeverity

        let viewModel = ReportIssueViewModel(user: user, vehicle: vehicle)
        viewModel.activeTripId = activeTripId
        _vm = StateObject(wrappedValue: viewModel)

        if let text = prefilledDescription,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

            _issues = State(initialValue: [
                IssueEntry(
                    category: prefilledCategory ?? "Mechanical",
                    severity: prefilledSeverity ?? "Medium",
                    description: text
                )
            ])
        } else {
            _issues = State(initialValue: [IssueEntry()])
        }
    }

    private let categories = ["Mechanical", "Electrical", "Tyre/Wheel", "Fluid Leak", "Bodywork", "Safety", "Other"]
    private let severities = ["Low", "Medium", "Critical"]

    var canSubmit: Bool {
        !vm.isSubmitting &&
        issues.allSatisfy { !$0.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                ScrollView {
                    VStack(spacing: 20) {

                        if let vehicle {
                            vehicleBanner(vehicle)
                        }

                        ForEach($issues) { $issue in
                            IssueCard(
                                issue: $issue,
                                index: issues.firstIndex(where: { $0.id == issue.id })! + 1,
                                total: issues.count,
                                categories: categories,
                                severities: severities,
                                onDelete: issues.count > 1 ? {
                                    withAnimation {
                                        issues.removeAll { $0.id == issue.id }
                                    }
                                } : nil
                            )
                        }

                        Button {
                            withAnimation {
                                issues.append(IssueEntry())
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Another Issue")
                            }
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.green.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            )
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 100)
                    }
                    .padding(.top)
                }

                submitBar
            }
            .navigationTitle(issues.count > 1 ? "Report \(issues.count) Issues" : "Report Issue")
            .navigationBarTitleDisplayMode(.inline)

            .alert("Issues Reported ✓", isPresented: $vm.submitSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text(issues.count > 1
                     ? "\(issues.count) issues have been submitted to the fleet manager. They will follow up shortly."
                     : "Your issue has been submitted to the fleet manager. They will follow up shortly.")
            }

            .alert("Submission Failed", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = vm.errorMessage {
                    Text(error)
                }
            }        }
    }

    // MARK: - Vehicle Banner
    private func vehicleBanner(_ vehicle: Vehicle) -> some View {
        HStack {
            Text(vehicle.name)
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Submit Bar
    private var submitBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {

                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.statusWarning)

                    Text(issues.count == 1 ? "1 Issue" : "\(issues.count) Issues")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.statusWarning.opacity(0.12), in: Capsule())

                Spacer()

                Button {
                    Task {
                        await vm.submitReports(issues: issues)
                        DispatchQueue.main.async {
                            vm.objectWillChange.send()
                        }
                    }
                } label: {
                    Group {
                        if vm.isSubmitting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)

                                Text("Submitting…")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        } else {
                            Text(issues.count > 1 ? "Submit All" : "Submit Report")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .background(
                        canSubmit ? AppTheme.primaryGreen : Color.secondary.opacity(0.4),
                        in: Capsule()
                    )
                }
                .disabled(!canSubmit)
                .animation(.easeInOut(duration: 0.2), value: canSubmit)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .padding(.bottom, 4)
            .background(.background)
        }
    }
}

// MARK: - Issue Card
private struct IssueCard: View {
    @Binding var issue: IssueEntry
    let index: Int
    let total: Int
    let categories: [String]
    let severities: [String]
    let onDelete: (() -> Void)?

    @FocusState private var descFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 7) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryGreen)
                            .frame(width: 24, height: 24)

                        Text("\(index)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Text("Issue \(index)")
                        .font(.system(size: 15, weight: .semibold))
                }

                Spacer()

                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.statusDanger)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider().padding(.horizontal, 16)

            // Category
            VStack(alignment: .leading, spacing: 10) {
                Text("Category")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)

                let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        CategoryChip(
                            title: cat,
                            isSelected: issue.category == cat
                        ) {
                            withAnimation(.snappy) {
                                issue.category = cat
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Severity
            VStack(alignment: .leading, spacing: 10) {
                Text("Severity")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)

                HStack(spacing: 8) {
                    ForEach(severities, id: \.self) { sev in
                        SeverityChip(
                            severity: sev,
                            isSelected: issue.severity == sev
                        ) {
                            withAnimation(.snappy) {
                                issue.severity = sev
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Description
            VStack(alignment: .leading, spacing: 10) {
                Text("Description")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $issue.description)
                        .focused($descFocused)
                        .frame(minHeight: 88)
                        .scrollContentBackground(.hidden)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .font(.system(size: 15))

                    if issue.description.isEmpty {
                        Text("Describe the issue in detail…")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(.placeholderText))
                            .padding(.top, 8)
                            .padding(.leading, 6)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            descFocused ? AppTheme.primaryGreen : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: descFocused)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.background)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - Category Chip
private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(
                    isSelected
                        ? AppTheme.primaryGreen
                        : Color(.secondarySystemGroupedBackground),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Severity Chip
private struct SeverityChip: View {
    let severity: String
    let isSelected: Bool
    let action: () -> Void

    var icon: String {
        switch severity {
        case "Low": return "arrow.down.circle.fill"
        case "Medium": return "minus.circle.fill"
        case "Critical": return "exclamationmark.circle.fill"
        default: return "circle.fill"
        }
    }

    var color: Color {
        switch severity {
        case "Low": return Color(hue: 0.38, saturation: 0.55, brightness: 0.72)
        case "Medium": return AppTheme.statusWarning
        case "Critical": return AppTheme.statusDanger
        default: return .secondary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))

                Text(severity)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? color : color.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}
