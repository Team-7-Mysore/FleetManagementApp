import SwiftUI
import Supabase

struct MaintenanceStaffPickerView: View {
    let vehicle: Vehicle
    private let supabase = SupabaseManager.shared.client
    @Environment(\.dismiss) var dismiss
    
    @State private var staff: [AppUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var taskDescription = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Issue Description") {
                    TextField("What needs repair?", text: $taskDescription)
                        .autocorrectionDisabled()
                }
                
                Section("Assign Technician") {
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
                            .disabled(isProcessing || taskDescription.isEmpty)
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
            .task { await fetchMaintenanceStaff() }
        }
    }
    
    private func fetchMaintenanceStaff() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let fetchedStaff: [AppUser] = try await supabase
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
        guard !taskDescription.isEmpty else { return }
        isProcessing = true
        Task { await saveMaintenanceTask(technician: technician) }
    }
    
    private func saveMaintenanceTask(technician: AppUser) async {
        do {
            let taskId = UUID()
            
            // 1. Create the task record
            let taskData: [String: AnyEncodable] = [
                "id": AnyEncodable(taskId),
                "vehicle_id": AnyEncodable(vehicle.id),
                "technician_id": AnyEncodable(technician.id),
                "description": AnyEncodable(taskDescription),
                "status": AnyEncodable("pending")
            ]
            try await supabase.from("maintenance_tasks").insert(taskData).execute()
            
            // 2. Update the vehicle status
            try await supabase.from("vehicles")
                .update(["status": AnyEncodable("under_maintenance")])
                .eq("vehicle_id", value: vehicle.id)
                .execute()
            
            // 3. Send Notification to Technician
            let notificationData: [String: AnyEncodable] = [
                "user_id": AnyEncodable(technician.id),
                "title": AnyEncodable("New Maintenance Task"),
                "message": AnyEncodable("You have been assigned to repair \(vehicle.name)"),
                "related_entity_id": AnyEncodable(taskId),
                "is_read": AnyEncodable(false)
            ]
            try await supabase.from("notifications").insert(notificationData).execute()
            
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                self.errorMessage = "Assignment failed: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }
}

// MARK: - Helper Type to fix "AnyEncodable" Error
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
