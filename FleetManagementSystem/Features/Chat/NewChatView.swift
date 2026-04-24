import SwiftUI

struct NewChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let currentUserId: UUID
    var onChatCreated: (ChatRoom) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    
    var filteredUsers: [AppUser] {
        if searchText.isEmpty {
            return viewModel.users
        } else {
            return viewModel.users.filter { user in
                user.name.lowercased().contains(searchText.lowercased()) ||
                user.email.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
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
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
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
