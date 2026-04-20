import SwiftUI
import MessageKit

struct ChatDetailView: View {
    @StateObject var viewModel: ChatViewModel
    let chatRoom: ChatRoom
    let currentUserId: UUID
    
    // In a real app, you'd fetch the recipient's name from participants
    @State private var recipientName: String = "Chat"
    
    var body: some View {
        ChatDetailRepresentable(
            chatRoomId: chatRoom.id,
            currentUser: Sender(senderId: currentUserId.uuidString, displayName: "Me"),
            otherUser: Sender(senderId: "recipient-id", displayName: recipientName),
            viewModel: viewModel
        )
        .navigationTitle(recipientName)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            recipientName = chatRoom.name ?? "Chat"
        }
    }
}
