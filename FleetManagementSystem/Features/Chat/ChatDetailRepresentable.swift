import SwiftUI
import MessageKit

struct ChatDetailRepresentable: UIViewControllerRepresentable {
    let chatRoomId: UUID
    let currentUser: Sender
    let otherUser: Sender
    let viewModel: ChatViewModel
    
    func makeUIViewController(context: Context) -> ChatViewController {
        return ChatViewController(
            chatRoomId: chatRoomId,
            currentUser: currentUser,
            otherUser: otherUser,
            viewModel: viewModel
        )
    }
    
    func updateUIViewController(_ uiViewController: ChatViewController, context: Context) {
        // UI updates are handled within ChatViewController via polling or property observers
    }
}
