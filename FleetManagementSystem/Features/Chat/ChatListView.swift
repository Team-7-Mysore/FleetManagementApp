import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingSearch = false
    
    // Placeholder current user ID
    let currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")! 
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Chat List
                    List {
                        // We can show recent chats or users based on filter
                        if viewModel.chats.isEmpty && viewModel.filteredUsers.isEmpty && !viewModel.isLoading {
                            ContentUnavailableView("No Messages", systemImage: "bubble.left.and.bubble.right", description: Text("Start a conversation with your team."))
                        } else {
                            // If searching/filtering, show users list to start new chat
                            if !viewModel.searchText.isEmpty || viewModel.selectedRoleFilter != "All" {
                                Section("Team Members") {
                                    ForEach(viewModel.filteredUsers) { user in
                                        ContactRow(user: user) {
                                            startChat(with: user)
                                        }
                                    }
                                }
                            } else {
                                // Default inbox view
                                Section {
                                    ForEach(viewModel.chats) { chat in
                                        NavigationLink {
                                            DetailWrapper(chat: chat, currentUserId: currentUserId, viewModel: viewModel)
                                        } label: {
                                            ChatInboxRow(chat: chat)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                // Floating Search Bar
                searchBar
                    .padding(.bottom, 30)
                    .padding(.horizontal, 20)
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .task {
                await viewModel.fetchChatRooms(userId: currentUserId)
                await viewModel.fetchUsers(currentUserId: currentUserId)
            }
            .refreshable {
                await viewModel.fetchChatRooms(userId: currentUserId)
                await viewModel.fetchUsers(currentUserId: currentUserId)
            }
        }
    }
    
    private var filterMenu: some View {
        Menu {
            Button("All") { viewModel.selectedRoleFilter = "All" }
            Button("Fleet Managers") { viewModel.selectedRoleFilter = "Fleet Manager" }
            Button("Maintenance") { viewModel.selectedRoleFilter = "Maintenance" }
            Button("Drivers") { viewModel.selectedRoleFilter = "Driver" }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundColor(Color(hex: "#A3352A"))
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search conversations", text: $viewModel.searchText)
                .font(.subheadline)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // Logic to start chat from contact list
    private func startChat(with user: AppUser) {
        Task {
            if let room = await viewModel.getOrCreateChatRoom(currentUserId: currentUserId, otherUserId: user.id) {
                // How to trigger navigation from here? 
                // In a real app, you'd use a navigation path or state.
                // For this demo, let's assume we refresh rooms and the user finds it.
                await viewModel.fetchChatRooms(userId: currentUserId)
                viewModel.searchText = ""
                viewModel.selectedRoleFilter = "All"
            }
        }
    }
}

struct ChatInboxRow: View {
    let chat: ChatRoom
    
    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator (dot)
            Circle()
                .fill(chat.updatedAt != nil ? (Color(hex: "#A3352A")) : .clear) // Simple unread logic
                .frame(width: 10, height: 10)
            
            // Avatar
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(chat.name?.prefix(1).uppercased() ?? "C")
                        .foregroundColor((Color(hex: "#A3352A")))
                        .fontWeight(.bold)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.name ?? "Direct Chat")
                        .font(.headline)
                    Spacer()
                    if let date = chat.updatedAt {
                        Text(date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(chat.type.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
    }
}

struct ContactRow: View {
    let user: AppUser
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(user.name.prefix(1).uppercased())
                            .foregroundColor((Color(hex: "#A3352A")))
                    }
                
                VStack(alignment: .leading) {
                    Text(user.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(user.role.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// Wrapper to bridge SwiftUI and MessageKit
struct DetailWrapper: View {
    let chat: ChatRoom
    let currentUserId: UUID
    let viewModel: ChatViewModel
    
    var body: some View {
        ChatDetailRepresentable(
            chatRoomId: chat.id,
            currentUser: Sender(senderId: currentUserId.uuidString, displayName: "Me"),
            otherUser: Sender(senderId: UUID().uuidString, displayName: chat.name ?? "User"), // In real app, fetch other participant
            viewModel: viewModel
        )
        .navigationTitle(chat.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
