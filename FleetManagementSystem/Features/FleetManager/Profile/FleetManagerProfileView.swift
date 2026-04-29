import SwiftUI
struct FleetManagerProfileView: View {
    let profile: UserProfile?
    let onSignOut: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSigningOut = false

    // Theme color matching your previous screens
    private let brandRed = Color.TechBlue

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Header (Initial Circle + Name)
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(brandRed.opacity(0.1))
                            .frame(width: 64, height: 64)
                            .overlay {
                                Text(getInitials(profile?.name ?? "F"))
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(brandRed)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile?.name ?? "Fleet Manager")
                                .font(.title3.weight(.bold))

                            HStack(spacing: 6) {
                                Image(systemName: profile?.role.systemImage ?? "wrench.and.screwdriver.fill")
                                    .font(.caption)
                                Text(profile?.role.displayName ?? "Fleet Manager")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(brandRed)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - Contact & Account Information
                Section("Contact Information") {
                    profileRow(icon: "envelope", title: "Email", value: profile?.email ?? "Not Available")
                }

                // MARK: - Preferences
                Section("Preferences") {
                    HStack {
                        Label("Language", systemImage: "globe")
                            .foregroundStyle(.primary)
                        Spacer()
                        LanguagePickerView()
                    }
                }

                // MARK: - App & Security Info
                Section("App Information") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                }

                // MARK: - Logout Button
                Section {
                    Button(role: .destructive) {
                        handleSignOut()
                    } label: {
                        HStack {
                            Spacer()
                            if isSigningOut {
                                ProgressView().tint(.red)
                            } else {
                                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                        }
                    }
                }
                .disabled(isSigningOut)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func handleSignOut() {
        Task {
            isSigningOut = true
            await onSignOut()
            isSigningOut = false
            dismiss()
        }
    }

    private func getInitials(_ name: String) -> String {
        let components = name.components(separatedBy: " ")
        if components.count > 1 {
            let first = components.first?.first ?? " "
            let last = components.last?.first ?? " "
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }

    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
