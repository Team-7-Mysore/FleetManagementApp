
//
//  StaffProfileView.swift
//  FleetManagementSystem
//
//  Profile detail screen for staff members (Simplified Form Style)
//

import SwiftUI
import Supabase

struct StaffProfileView: View {
    let staff: StaffUser

    @Environment(\.dismiss) private var dismiss
    @State private var creatorName: String? = nil
    @State private var isDeactivating = false
    @State private var errorMessage: String? = nil
    @State private var showAlert = false
    @State private var showDeactivateConfirmation = false

    private var accentColor: Color {
        switch staff.role {
        case .driver:      return Color(red: 59/255,  green: 13/255,  blue: 17/255)
        case .maintenance: return Color(red: 30/255,  green: 80/255,  blue: 160/255)
        case .manager:     return Color(red: 40/255,  green: 120/255, blue: 70/255)
        }
    }

    var body: some View {
        Form {
            // MARK: Profile Header
            Section {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.12))
                            .frame(width: 70, height: 70)
                        
                        Text(staff.initials)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(staff.name)
                            .font(.title3.weight(.bold))
                        
                        Text(staff.role.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let status = staff.status {
                            Text(status.displayName)
                                .font(.caption.weight(.bold))
                                .foregroundColor(statusColor(status))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(statusColor(status).opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            // MARK: Personal Details
            Section(header: Text("Staff Information")) {
                LabeledContent("Staff ID", value: String(staff.user_id.prefix(8).uppercased()))
                LabeledContent("Email", value: staff.email)
                if let phone = staff.phone_no, !phone.isEmpty {
                    LabeledContent("Phone", value: phone)
                }
                if let cname = creatorName {
                    LabeledContent("Created By", value: cname)
                }
            }

            // MARK: Performance & Activity (Simplified)
            Section(header: Text("Overview")) {
                LabeledContent {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("4.9")
                    }
                } label: {
                    Text("Safety Rating")
                }
                
                LabeledContent("Total Distance", value: "142,800 mi")
                LabeledContent("Current Vehicle", value: "Vehicle 204")
            }

            // MARK: Actions
            Section {
                Button(role: .destructive) {
                    showDeactivateConfirmation = true
                } label: {
                    if isDeactivating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Deactivate Staff Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isDeactivating || staff.status == .inactive)
            }
        }
        .alert(
            "Deactivate Account?",
            isPresented: $showDeactivateConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                Task {
                    await deactivateStaff()
                }
            }
        } message: {
            Text("Are you sure you want to deactivate \(staff.name)'s account?")
        }
        .alert("Error Deactivating", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred.")
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchCreatorName()
        }
    }

    private func deactivateStaff() async {
        await MainActor.run { isDeactivating = true }
        do {
            try await SupabaseManager.shared.client
                .from("users")
                .update(["status": "inactive"])
                .eq("user_id", value: staff.user_id)
                .execute()
            
            await MainActor.run {
                isDeactivating = false
                dismiss() // Close the profile view since the account is now inactive
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showAlert = true
                self.isDeactivating = false
            }
        }
    }

    private func fetchCreatorName() async {
        guard let creatorId = staff.created_by, creatorName == nil else { return }
        do {
            let records: [CreatorRecord] = try await SupabaseManager.shared.client
                .from("users")
                .select("name")
                .eq("user_id", value: creatorId)
                .limit(1)
                .execute()
                .value
            
            if let fetchedName = records.first?.name {
                await MainActor.run { self.creatorName = fetchedName }
            }
        } catch {
            print("Failed to fetch creator name: \(error)")
        }
    }

    private func statusColor(_ status: AccountStatus) -> Color {
        switch status {
        case .active:   return Color(red: 0.1, green: 0.72, blue: 0.35)
        case .pending:  return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .inactive: return .gray
        }
    }
}

private struct CreatorRecord: Decodable {
    let name: String
}

//#Preview {
//    StaffProfileView(staff: StaffUser(
//        user_id: "D12345678",
//        name: "Amit Sharma",
//        email: "amit.garage@fleet.com",
//        role: .maintenance,
//        phone_no: "9988776655",
//        username: "amit_s",
//        status: .active,
//        created_by: nil
//    ))
//}
