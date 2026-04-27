import SwiftUI

struct ChatListView: View {
    let currentUserId: UUID
    @StateObject private var viewModel = ChatViewModel()
    @State private var isShowingNewChat = false
    @State private var pendingChatRoom: ChatRoom? = nil
    @State private var queuedChatRoom: ChatRoom? = nil
    private let accent = AppTheme.primaryGreen

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                List {
                    if viewModel.chats.isEmpty && !viewModel.isLoading {
                        ContentUnavailableView(
                            "No Messages",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Start a conversation with your team.")
                        )
                        .listRowSeparator(.hidden)
                    } else {
                        Section {
                            ForEach(filteredChats) { chat in
                                NavigationLink {
                                    DetailWrapper(chat: chat, currentUserId: currentUserId, viewModel: viewModel)
                                } label: {
                                    let otherUserName = getOtherUserName(for: chat)
                                    ChatInboxRow(chat: chat, accent: accent, otherUserName: otherUserName)
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }

            searchBar
                .padding(.bottom, 30)
                .padding(.horizontal, 20)
        }
        .navigationTitle("Chat")
        .tint(accent)
        .navigationDestination(item: $pendingChatRoom) { chat in
            DetailWrapper(chat: chat, currentUserId: currentUserId, viewModel: viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    filterMenu

                    Button {
                        isShowingNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(accent)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingNewChat, onDismiss: {
            // Navigate only after sheet closes to keep transition clean.
            if let room = queuedChatRoom {
                pendingChatRoom = room
                queuedChatRoom = nil
            }
        }) {
            NewChatView(viewModel: viewModel, currentUserId: currentUserId) { room in
                print("🚀 Room received from NewChatView: \(room.id)")
                queuedChatRoom = room
                isShowingNewChat = false
            }
        }
        .task {
            await viewModel.fetchUsers(currentUserId: currentUserId)
            await viewModel.fetchChatRooms(userId: currentUserId)
        }
        .refreshable {
            await viewModel.fetchUsers(currentUserId: currentUserId)
            await viewModel.fetchChatRooms(userId: currentUserId)
        }
    }

    // MARK: - Filtered Chats (UI-level, reliable)
    private var filteredChats: [ChatRoom] {
        let query = viewModel.searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // No search → show all
        guard !query.isEmpty else { return viewModel.chats }

        return viewModel.chats.filter { chat in
            let name = (getOtherUserName(for: chat) ?? "").lowercased()
            let message = (chat.lastMessage ?? "").lowercased()

            return name.contains(query) || message.contains(query)
        }
    }

    private func getOtherUserName(for chat: ChatRoom) -> String? {
        guard let otherUserId = chat.participantIds.first(where: { $0 != currentUserId }) else {
            return nil
        }
        return viewModel.users.first(where: { $0.id == otherUserId })?.name
    }

    private var filterMenu: some View {
        Menu {
            Button("All") { viewModel.selectedRoleFilter = "All" }
            Button("Fleet Managers") { viewModel.selectedRoleFilter = "Fleet Manager" }
            Button("Maintenance") { viewModel.selectedRoleFilter = "Maintenance" }
            Button("Drivers") { viewModel.selectedRoleFilter = "Driver" }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundColor(accent)
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
}

struct ChatInboxRow: View {
    let chat: ChatRoom
    let accent: Color
    var otherUserName: String? = nil

    private var displayName: String {
        if let name = chat.name, !name.isEmpty {
            return name
        }
        return otherUserName ?? "Chat"
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(chat.updatedAt != nil ? accent : .clear)
                .frame(width: 10, height: 10)

            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 55, height: 55)

                Text(displayName.prefix(1).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    if let date = chat.updatedAt {
                        Text(formatDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(chat.lastMessage ?? "Tap to start messaging...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.trailing, 20)
            }
        }
        .padding(.vertical, 10)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Wrapper to bridge SwiftUI and MessageKit
struct DetailWrapper: View {
    let chat: ChatRoom
    let currentUserId: UUID
    let viewModel: ChatViewModel

    private var otherUserInfo: (id: UUID, name: String)? {
        guard let otherUserId = chat.participantIds.first(where: { $0 != currentUserId }) else {
            return nil
        }
        guard let user = viewModel.users.first(where: { $0.id == otherUserId }) else {
            return nil
        }
        return (id: otherUserId, name: user.name)
    }

    var body: some View {
        ChatDetailRepresentable(
            chatRoomId: chat.id,
            currentUser: Sender(senderId: currentUserId.uuidString, displayName: "Me"),
            otherUser: Sender(
                senderId: otherUserInfo?.id.uuidString ?? UUID().uuidString,
                displayName: otherUserInfo?.name ?? "Chat"
            ),
            viewModel: viewModel, accentUIColor: .tintColor
        )
        .navigationTitle(otherUserInfo?.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
