import SwiftUI

struct MaintenanceProfileView: View {
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
                                .fill(Color(hex: "#A3352A").opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#A3352A"))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile?.name ?? "Maintenance Staff")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(profile?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.caption)
                                Text("Maintenance Personnel")
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
                    .listRowBackground(Color(hex: "#A3352A"))
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
    MaintenanceProfileView(
        profile: UserProfile(
            userId: UUID(),
            name: "John Mechanic",
            email: "john@example.com",
            role: .maintenance,
            phoneNumber: "+1 234 567 8900",
            createdAt: nil,
            createdBy: nil,
            username: "john_mechanic"
        ),
        onSignOut: {}
    )
}
