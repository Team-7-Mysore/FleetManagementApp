
//
//  StaffProfileView.swift
//  FleetManagementSystem
//
//  Profile detail screen for staff members (Simplified Form Style)
//

import SwiftUI

struct StaffProfileView: View {
    let staff: StaffUser

    private var accentColor: Color {
        switch staff.role {
        case .driver:      return Color(red: 59/255,  green: 13/255,  blue: 17/255)
        case .maintenance: return Color(red: 30/255,  green: 80/255,  blue: 160/255)
        case .fleetManager:     return Color(red: 40/255,  green: 120/255, blue: 70/255)
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
                    // Action for deactivating/removing staff
                } label: {
                    Text("Deactivate Staff Account")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusColor(_ status: AccountStatus) -> Color {
        switch status {
        case .active:   return Color(red: 0.1, green: 0.72, blue: 0.35)
        case .pending:  return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .inactive: return .gray
        }
    }
}

#Preview {
    StaffProfileView(staff: StaffUser(
        user_id: "D12345678",
        name: "Amit Sharma",
        email: "amit.garage@fleet.com",
        role: .maintenance,
        phone_no: "9988776655",
        username: "amit_s",
        status: .active
    ))
}
