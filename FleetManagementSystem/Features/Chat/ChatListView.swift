import SwiftUI
import Supabase

struct ChatListView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var isShowingNewChat = false
    @State private var accent = Color(red: 0.639, green: 0.207, blue: 0.165)

    // Resolved from Supabase auth session
    @State private var currentUserId: UUID = UUID()

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
                                ForEach(viewModel.chats) { chat in
                                    NavigationLink(value: chat) {
                                        ChatInboxRow(chat: chat, accent: accent)
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
            .navigationDestination(for: ChatRoom.self) { chat in
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
            .sheet(isPresented: $isShowingNewChat) {
                NewChatView(viewModel: viewModel, currentUserId: currentUserId) { room in
                    navigationPath.append(room)
                }
            }
            .task {
                await resolveCurrentUser()
                await viewModel.fetchChatRooms(userId: currentUserId)
                await viewModel.fetchUsers(currentUserId: currentUserId)
            }
            .refreshable {
                await viewModel.fetchChatRooms(userId: currentUserId)
                await viewModel.fetchUsers(currentUserId: currentUserId)
            }
        }
    }

    // MARK: - Resolve current user from Supabase session
    private func resolveCurrentUser() async {
        do {
            let user = try await SupabaseManager.shared.client.auth.user()
            currentUserId = user.id
        } catch {
            print("❌ ChatListView: could not resolve current user:", error)
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

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(chat.updatedAt != nil ? accent : .clear)
                .frame(width: 10, height: 10)

            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 55, height: 55)

                Text(chat.name?.prefix(1).uppercased() ?? "C")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(chat.name ?? "Direct Chat")
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

    var body: some View {
        ChatDetailRepresentable(
            chatRoomId: chat.id,
            currentUser: Sender(senderId: currentUserId.uuidString, displayName: "Me"),
            otherUser: Sender(senderId: UUID().uuidString, displayName: chat.name ?? "User"),
            viewModel: viewModel
        )
        .navigationTitle(chat.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
