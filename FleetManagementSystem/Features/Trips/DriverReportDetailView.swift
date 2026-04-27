import SwiftUI
import Supabase

struct DriverReportDetailView: View {
    let report: DriverReport
    @Environment(\.dismiss) private var dismiss
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    // Assignment State
    @State private var maintenancePersonnel: [StaffUser] = []
    @State private var selectedPersonnelId: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header / Status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DRIVER REPORT")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Text("#\(report.id.uuidString.prefix(8).uppercased())")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    statusBadge
                }
                .padding(.top)
                
                // Vehicle Info
                if let vehicle = report.vehicle {
                    CardView {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: vehicle.vehicleType?.sfSymbol ?? "car.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vehicle.vehicleName ?? "Unknown Vehicle")
                                    .font(.headline)
                                Text(vehicle.numberPlate ?? "No Plate")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Report Details
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeaderView(title: "REPORT DETAILS")
                    
                    CardView {
                        VStack(alignment: .leading, spacing: 16) {
                            DetailRow(label: "Category", value: report.category.rawValue.capitalized, icon: "tag.fill")
                            DetailRow(label: "Severity", value: report.severity.rawValue.capitalized, icon: "exclamationmark.triangle.fill", color: severityColor)
                            DetailRow(label: "Date", value: report.createdAt?.formatted() ?? "N/A", icon: "calendar")
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                
                                Text(report.description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                // Assignment Section
                if report.status == .reported {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeaderView(title: "ASSIGN TO MAINTENANCE")
                        
                        CardView {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select Maintenance Personnel")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                
                                Picker("Personnel", selection: $selectedPersonnelId) {
                                    Text("Choose a person...").tag(Optional<String>.none)
                                    ForEach(maintenancePersonnel) { person in
                                        HStack {
                                            Text(person.name)
                                            Spacer()
                                            Text("(\(person.email))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }.tag(Optional(person.user_id))
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        Button(action: {
                            Task { await assignAndApprove() }
                        }) {
                            if isUpdating {
                                ProgressView().tint(.white)
                            } else {
                                Text("Approve & Assign to Maintenance")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedPersonnelId == nil ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isUpdating || selectedPersonnelId == nil)
                        
                        Button(action: {
                            Task { await updateReportStatus(.acknowledged) }
                        }) {
                            Text("Just Acknowledge (No Assignment)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isUpdating)
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Report Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            await fetchMaintenancePersonnel()
        }
    }
    
    private var statusBadge: some View {
        Text(report.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.1))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch report.status {
        case .reported: return .orange
        case .acknowledged: return .blue
        case .convertedToWorkOrder: return .purple
        case .resolved: return .green
        }
    }
    
    private var severityColor: Color {
        switch report.severity {
        case .low: return .green
        case .medium: return .orange
        case .critical: return .red
        }
    }
    
    private func fetchMaintenancePersonnel() async {
        do {
            let fetched: [StaffUser] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("role", value: "maintenance")
                .execute()
                .value
            
            await MainActor.run {
                self.maintenancePersonnel = fetched
            }
        } catch {
            print("🚨 Failed to fetch maintenance staff: \(error)")
        }
    }
    
    private func assignAndApprove() async {
        guard let personnelId = selectedPersonnelId else { return }
        isUpdating = true
        errorMessage = nil
        
        do {
            // 1. Create record in maintenance_issues
            struct MaintenanceIssueInsert: Encodable {
                let vehicle_id: UUID?
                let maintenance_personnel_id: String
                let issue_summary: String
                let description: String
                let status: String
            }
            
            let newIssue = MaintenanceIssueInsert(
                vehicle_id: report.vehicleId,
                maintenance_personnel_id: personnelId,
                issue_summary: "\(report.category.rawValue.capitalized) Issue: \(report.severity.rawValue.capitalized)",
                description: report.description,
                status: "pending"
            )
            
            try await SupabaseManager.shared.client
                .from("maintenance_issues")
                .insert(newIssue)
                .execute()
            
            // 2. Update driver_reports status
            struct StatusUpdate: Encodable {
                let status: String
            }
            
            try await SupabaseManager.shared.client
                .from("driver_reports")
                .update(StatusUpdate(status: "acknowledged"))
                .eq("id", value: report.id.uuidString)
                .execute()
            
            await MainActor.run {
                isUpdating = false
                dismiss()
            }
        } catch {
            print("🚨 Assignment failed: \(error)")
            await MainActor.run {
                errorMessage = "Failed to assign. Please check your connection."
                isUpdating = false
            }
        }
    }
    
    private func updateReportStatus(_ newStatus: DriverReportStatus) async {
        isUpdating = true
        errorMessage = nil
        
        do {
            struct StatusUpdate: Encodable {
                let status: String
            }
            
            try await SupabaseManager.shared.client
                .from("driver_reports")
                .update(StatusUpdate(status: newStatus.rawValue))
                .eq("id", value: report.id.uuidString)
                .execute()
            
            await MainActor.run {
                isUpdating = false
                dismiss()
            }
        } catch {
            print("🚨 Failed to update report status: \(error)")
            await MainActor.run {
                errorMessage = "Failed to update status. Please try again."
                isUpdating = false
            }
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    var color: Color = .primary
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}
