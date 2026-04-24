import SwiftUI

struct NewChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let currentUserId: UUID
    var onChatCreated: (ChatRoom) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var selectedRole: String = "All"
    
    var filteredUsers: [AppUser] {
        var result = viewModel.users

        // 🔍 Search
        if !searchText.isEmpty {
            let term = searchText.lowercased()
            result = result.filter { user in
                user.name.lowercased().contains(term) || user.email.lowercased().contains(term)
            }
        }

        // 🎯 Role filter
        if selectedRole != "All" {
            let roleValue = selectedRole.lowercased().replacingOccurrences(of: " ", with: "_")
            result = result.filter { $0.role.lowercased() == roleValue }
        }

        return result
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filteredUsers.isEmpty {
                    Text("No users found")
                        .foregroundColor(.gray)
                } else {
                    ForEach(filteredUsers) { user in
                        Button {
                            startNewChat(with: user)
                        } label: {
                            UserRowView(user: user)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isCreatingRoom)
                    }
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.primaryGreen)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All") { selectedRole = "All" }
                        Button("Fleet Manager") { selectedRole = "fleet_manager" }
                        Button("Maintenance") { selectedRole = "maintenance" }
                        Button("Driver") { selectedRole = "driver" }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task {
                await viewModel.fetchUsers(currentUserId: currentUserId)
            }
        }
    }
    
    private func startNewChat(with user: AppUser) {
        Task {
            if let room = await viewModel.getOrCreateChatRoom(
                currentUserId: currentUserId,
                otherUserId: user.id
            ) {
                print("✅ Room ready, navigating: \(room.id)")
                await MainActor.run {
                    onChatCreated(room)
                }
            }
        }
    }
}
