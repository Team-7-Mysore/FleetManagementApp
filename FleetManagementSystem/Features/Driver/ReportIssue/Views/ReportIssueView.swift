import SwiftUI

// MARK: - Report Issue View
struct ReportIssueView: View {
    let user: User
    let vehicle: Vehicle?
    @Environment(\.dismiss) private var dismiss

    @State private var issueCategory = "Mechanical"
    @State private var severity = "Medium"
    @State private var description = ""
    @State private var showConfirmation = false

    private let categories = ["Mechanical", "Electrical", "Tire/Wheel", "Fluid Leak", "Body Damage", "Safety", "Other"]
    private let severities = ["Low", "Medium", "Critical"]

    var body: some View {
        NavigationStack {
            Form {
                // Vehicle info
                if let vehicle {
                    Section("Vehicle") {
                        HStack(spacing: 12) {
                            Image(systemName: vehicle.imageSystemName)
                                .foregroundStyle(AppTheme.primaryGreen)
                            VStack(alignment: .leading) {
                                Text(vehicle.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(vehicle.licensePlate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Category
                Section("Issue Category") {
                    Picker("Category", selection: $issueCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.primaryGreen)
                }

                // Severity
                Section("Severity") {
                    VStack(spacing: 2) {
                        Slider(
                            value: Binding(
                                get: { Double(severities.firstIndex(of: severity) ?? 1) },
                                set: { newValue in
                                    withAnimation(.snappy) {
                                        severity = severities[Int(newValue)]
                                    }
                                }
                            ),
                            in: 0...Double(severities.count - 1),
                            step: 1.0
                        )
                        .tint(colorForSeverity(severity))
                        
                        HStack {
                            Text("Low")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(colorForSeverity("Low"))
                            Spacer()
                            Text("Critical")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(colorForSeverity("Critical"))
                        }
                    }
                }

                // Description
                Section("Description") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                        
                        if description.isEmpty {
                            Text("Provide as much detail as possible...")
                                .foregroundStyle(Color(.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                }

                // Submit
                Section {
                    HStack {
                        Spacer()
                        Button {
                            showConfirmation = true
                        } label: {
                            Text("Submit Report")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(AppTheme.primaryGreen)
                                .clipShape(Capsule())
                        }
                        .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Issue Reported", isPresented: $showConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your issue report has been submitted to the fleet manager. They will follow up shortly.")
            }
        }
    }

    private func colorForSeverity(_ sev: String) -> Color {
        switch sev {
        case "Low": return AppTheme.primaryGreen
        case "Medium": return AppTheme.statusWarning
        case "Critical": return AppTheme.statusDanger
        default: return .secondary
        }
    }
}
