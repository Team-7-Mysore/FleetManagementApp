import SwiftUI
import Supabase

struct MaintenanceStaffPickerView: View {
    let vehicle: Vehicle
    @Environment(\.dismiss) var dismiss
    
    @State private var staff: [AppUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @State private var issueSummary = ""
    @State private var taskDescription = ""
    @State private var isProcessing = false
    

    var driverReportId: UUID? = nil
    var initialSummary: String? = nil
    var initialDescription: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Issue Details") {
                    TextField("Summary (e.g. Engine Overheating)", text: $issueSummary)
                        .autocorrectionDisabled()
                    
                    TextEditor(text: $taskDescription)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if taskDescription.isEmpty {
                                Text("Detailed description of the problem...")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                
                Section("Assign Maintenance Personnel") {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if let error = errorMessage {
                        Text(error).foregroundColor(.red).font(.caption)
                    } else if staff.isEmpty {
                        Text("No staff found with 'maintenance' role.").foregroundColor(.secondary)
                    } else {
                        ForEach(staff) { person in
                            Button {
                                assignTechnician(person)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(person.name).font(.body.weight(.medium))
                                        Text(person.email).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if isProcessing {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "person.fill.badge.plus").foregroundColor(.blue)
                                    }
                                }
                            }
                            .disabled(isProcessing || taskDescription.isEmpty || issueSummary.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("Assign Maintenance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                // Auto-fill if provided
                if let summary = initialSummary {
                    self.issueSummary = summary
                }
                if let desc = initialDescription {
                    self.taskDescription = desc
                }
                
                await fetchMaintenanceStaff()
            }
        }
    }
    
  
    
    private func fetchMaintenanceStaff() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let fetchedStaff: [AppUser] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("role", value: "maintenance")
                .execute()
                .value
            await MainActor.run {
                self.staff = fetchedStaff
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Load Error: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func assignTechnician(_ technician: AppUser) {
        guard !taskDescription.isEmpty && !issueSummary.isEmpty else { return }
        isProcessing = true
        Task { await saveMaintenanceTask(technician: technician) }
    }
    
    private func saveMaintenanceTask(technician: AppUser) async {
        do {
            let taskId = UUID()
            
          
            let issueData: [String: AnyEncodable] = [
                "issue_id": AnyEncodable(taskId),
                "vehicle_id": AnyEncodable(vehicle.id),
                "maintenance_personnel_id": AnyEncodable(technician.id),
                "description": AnyEncodable(taskDescription),
                "issue_summary": AnyEncodable(issueSummary)
            ]
            try await SupabaseManager.shared.client.from("maintenance_issues").insert(issueData).execute()
            
            try await SupabaseManager.shared.client.from("vehicles")
                .update(["status": AnyEncodable("under_maintenance")])
                .eq("vehicle_id", value: vehicle.id)
                .execute()
            
            
            let session = try await SupabaseManager.shared.client.auth.session
            let currentUserId = session.user.id
            
            let notificationData: [String: AnyEncodable] = [
                "recipient_id": AnyEncodable(technician.id),
                "sender_id": AnyEncodable(currentUserId),
                "type": AnyEncodable("Maintenance"),
                "title": AnyEncodable("New Task: \(issueSummary)"),
                "message": AnyEncodable("You have been assigned to repair \(vehicle.name)"),
                "related_entity_id": AnyEncodable(taskId),
                "is_read": AnyEncodable(false)
            ]
            try await SupabaseManager.shared.client.from("notifications").insert(notificationData).execute()
            
            
            if let reportId = driverReportId {
                struct StatusUpdate: Encodable { let status: String }
                try await SupabaseManager.shared.client
                    .from("driver_reports")
                    .update(StatusUpdate(status: "acknowledged"))
                    .eq("id", value: reportId.uuidString)
                    .execute()
            }
            
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                self.errorMessage = "Assignment failed: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }
} 
