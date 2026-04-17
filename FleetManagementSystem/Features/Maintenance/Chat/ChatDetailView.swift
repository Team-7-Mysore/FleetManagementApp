import SwiftUI

struct ChatDetailView: View {
    @StateObject var viewModel: ChatViewModel
    let chatRoom: ChatRoom
    let currentUserId: UUID
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isCurrentUser: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: viewModel.messages) { _ in
                    if let lastMessageId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastMessageId, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessageId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastMessageId, anchor: .bottom)
                    }
                }
            }
            
            // Input Bar
            Divider()
            HStack(spacing: 12) {
                TextField("Type a message...", text: $viewModel.currentMessage, axis: .vertical)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(5)
                
                Button {
                    Task {
                        await viewModel.sendMessage(chatRoomId: chatRoom.id, senderId: currentUserId)
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color(hex:"#A3352A"))
                        .clipShape(Circle())
                }
                .disabled(viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(chatRoom.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchMessages(chatRoomId: chatRoom.id)
        }
    }
}
