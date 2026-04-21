import SwiftUI

struct FleetManagerProfileView: View {
    let profile: UserProfile?
    let onSignOut: () async -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isSigningOut = false
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        // Profile Avatar
                        ZStack {
                            Circle()
                                .fill(Color.TechBlue.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.TechBlue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile?.name ?? "Fleet Manager")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(profile?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "car.2.fill")
                                    .font(.caption)
                                Text("Fleet Manager")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Account Information
                Section("Account Information") {
                    if let profile = profile {
                        HStack {
                            Text("User ID")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(profile.userId.uuidString.prefix(8).uppercased())
                                .foregroundColor(.primary)
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        if let username = profile.username {
                            HStack {
                                Text("Username")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(username)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        if let phoneNumber = profile.phoneNumber {
                            HStack {
                                Text("Phone")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(phoneNumber)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                
                // Sign Out Section
                Section {
                    Button(action: {
                        Task {
                            isSigningOut = true
                            await onSignOut()
                            dismiss()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isSigningOut {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .tint(.white)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.TechBlue)
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FleetManagerProfileView(
        profile: UserProfile(
            userId: UUID(),
            name: "Sarah Manager",
            email: "sarah@example.com",
            role: .fleetManager,
            phoneNumber: "+1 234 567 8900",
            createdAt: nil,
            createdBy: nil,
            username: "sarah_manager"
        ),
        onSignOut: {}
    )
}
