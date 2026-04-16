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
    private let severities = ["Low", "Medium", "High", "Critical"]

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
                    Picker("Severity", selection: $severity) {
                        ForEach(severities, id: \.self) { sev in
                            Text(sev).tag(sev)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Description
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }

                // Submit
                Section {
                    Button {
                        showConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Submit Report", systemImage: "exclamationmark.triangle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .background(AppTheme.primaryGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .tint(AppTheme.primaryGreen)
                }
            }
            .alert("Issue Reported", isPresented: $showConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your issue report has been submitted to the fleet manager. They will follow up shortly.")
            }
        }
    }
}
