import SwiftUI
import MessageKit

struct ChatDetailView: View {
    @StateObject var viewModel: ChatViewModel
    let chatRoom: ChatRoom
    let currentUserId: UUID
    let globalAccent: Color
    
    // In a real app, you'd fetch the recipient's name from participants
    @State private var recipientName: String = "Chat"
    
    private var otherUserInfo: (id: UUID, name: String, role: String?)? {
        guard let otherUserId = chatRoom.participantIds.first(where: { $0 != currentUserId }) else {
            return nil
        }
        guard let user = viewModel.users.first(where: { $0.id == otherUserId }) else {
            return nil
        }
        return (id: otherUserId, name: user.name, role: user.role)
    }
    
    var body: some View {
        ChatDetailRepresentable(
            chatRoomId: chatRoom.id,
            currentUser: Sender(senderId: currentUserId.uuidString, displayName: "Me"),
            otherUser: Sender(
                senderId: otherUserInfo?.id.uuidString ?? "recipient-id",
                displayName: recipientName
            ),
            viewModel: viewModel,
            accentUIColor: UIColor(globalAccent)
        )
        .navigationTitle(recipientName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            recipientName = chatRoom.name ?? "Chat"
        }
    }
}

