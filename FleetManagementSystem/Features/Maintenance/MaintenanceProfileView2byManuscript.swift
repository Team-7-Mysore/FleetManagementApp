import SwiftUI

struct ProfileView: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = true

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)

                    VStack(alignment: .leading) {
                        Text("Maintenance User")
                            .font(.headline)
                        Text("Ready for work")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 8)
                }
                .padding(.vertical, 8)
            }

            Section {
                Button(action: {
                    // Add your Supabase sign out logic here later
                    // Task { try? await SupabaseManager.shared.client.auth.signOut() }

                    // This flips the switch and shows the LoginView
                    isLoggedIn = false
                }) {
                    HStack {
                        Spacer()
                        Text("Log Out")
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profile")
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
