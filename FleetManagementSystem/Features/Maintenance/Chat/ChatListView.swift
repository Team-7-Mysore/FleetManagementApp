import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel = ChatViewModel()
    
    // Placeholder current user ID - in a real app, this would come from your Auth system
    let currentUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")! 
    
    var body: some View {
        NavigationStack {
            List(viewModel.chats) { chat in
                NavigationLink(destination: ChatDetailView(viewModel: viewModel, chatRoom: chat, currentUserId: currentUserId)) {
                    ChatRoomRow(chat: chat)
                }
            }
            .navigationTitle("Messages")
            .listStyle(PlainListStyle())
            .overlay {
                if viewModel.isLoading && viewModel.chats.isEmpty {
                    ProgressView()
                } else if viewModel.chats.isEmpty {
                    ContentUnavailableView("No Chats", systemImage: "bubble.left.and.exclamationmark.bubble.right", description: Text("Your conversation list is empty."))
                }
            }
            .task {
                await viewModel.fetchChatRooms(userId: currentUserId)
            }
            .refreshable {
                await viewModel.fetchChatRooms(userId: currentUserId)
            }
        }
    }
}

struct ChatRoomRow: View {
    let chat: ChatRoom
    
    var body: some View {
        HStack(spacing: 15) {
            // Avatar Placeholder
            Circle()
                .fill(Color(hex:"#A3352A").opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(chat.name?.prefix(1).uppercased() ?? "C")
                        .font(.headline)
                        .foregroundColor(Color(hex:"#A3352A"))
                }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(chat.name ?? "Group Chat")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let updatedAt = chat.updatedAt {
                        Text(updatedAt, style: .time)
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

#Preview {
    ChatListView()
}
