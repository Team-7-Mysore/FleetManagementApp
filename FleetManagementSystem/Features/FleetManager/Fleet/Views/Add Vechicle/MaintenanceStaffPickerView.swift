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
                // FIX 1: Ensure this function exists below
                await fetchMaintenanceStaff()
            }
        }
    }
    
    // MARK: - Networking Functions
    
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
            
            // FIX 2: AnyEncodable is used here, defined at the bottom
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
            
            // NOTE: I changed "user_id" to "recipient_id" because that is what your notifications table uses!
            let notificationData: [String: AnyEncodable] = [
                "recipient_id": AnyEncodable(technician.id),
                
                // 🚨 NEW: Tell the mechanic who sent this!
                // (Replace this with however you get the logged-in manager's ID, or hardcode your UUID to test it)
                "sender_id": AnyEncodable("3695958a-2a6e-4cac-a311-7541e5c03a2f"),
                
                "type": AnyEncodable("Maintenance"), // <-- Add the type so the mechanic's view catches it!
                "title": AnyEncodable("New Task: \(issueSummary)"),
                "message": AnyEncodable("You have been assigned to repair \(vehicle.name)"),
                "related_entity_id": AnyEncodable(taskId), // This is the issue_id
                "is_read": AnyEncodable(false)
            ]
            try await SupabaseManager.shared.client.from("notifications").insert(notificationData).execute()
            
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                self.errorMessage = "Assignment failed: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }
} // End of MaintenanceStaffPickerView

// MARK: - Helpers
// FIX 3: AnyEncodable MUST be outside the View struct to be easily found by the compiler
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
