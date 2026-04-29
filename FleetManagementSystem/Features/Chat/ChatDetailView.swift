import SwiftUI
import MessageKit

struct ChatDetailView: View {
    @StateObject var viewModel: ChatViewModel
    let chatRoom: ChatRoom
    let currentUserId: UUID
    let globalAccent: Color

    @State private var messageText: String = ""
    @FocusState private var isInputFocused: Bool

    private var otherParticipantId: UUID? {
        guard chatRoom.participantIds.count == 2 else { return nil }
        return chatRoom.participantIds.first(where: { $0 != currentUserId })
    }

    private var otherUserInfo: (id: UUID, name: String, role: String?)? {
        guard let otherUserId = otherParticipantId else { return nil }
        guard let user = viewModel.users.first(where: { $0.id == otherUserId }) else {
            return nil
        }
        return (id: otherUserId, name: user.name, role: user.role)
    }

    private var displayName: String {
        if chatRoom.participantIds.count > 2 {
            return chatRoom.name ?? "Group"
        } else {
            return otherUserInfo?.name ?? "Chat"
        }
    }

    var body: some View {
        ChatDetailRepresentable(
            chatRoomId: chatRoom.id,
            currentUser: Sender(
                senderId: currentUserId.uuidString,
                displayName: "Me"
            ),
            otherUser: Sender(
                senderId: otherParticipantId?.uuidString ?? "recipient-id",
                displayName: displayName
            ),
            viewModel: viewModel,
            accentUIColor: UIColor(globalAccent)
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            chatInputBar
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.setCurrentUserId(currentUserId)
            markLatestMessageRead()
        }
        .onReceive(viewModel.$messages) { _ in
            markLatestMessageRead()
        }
    }

    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                TextField("Aa", text: $messageText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .focused($isInputFocused)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(.systemGray3)
                            : globalAccent
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        messageText = ""

        Task {
            await viewModel.sendMessage(
                chatRoomId: chatRoom.id,
                senderId: currentUserId,
                content: content
            )
        }
    }

    private func markLatestMessageRead() {
        guard let latest = viewModel.messages.last else { return }
        guard let otherId = otherParticipantId else { return }
        guard latest.senderId == otherId else { return }
        let createdAt = latest.createdAt ?? Date()
        Task {
            await viewModel.markChatRead(
                chatRoomId: chatRoom.id,
                userId: currentUserId,
                readAt: createdAt
            )
        }
    }
}
