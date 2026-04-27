import SwiftUI
import MessageKit

struct ChatDetailRepresentable: UIViewControllerRepresentable {
    let chatRoomId: UUID
    let currentUser: Sender
    let otherUser: Sender
    let viewModel: ChatViewModel
    let accentUIColor: UIColor
    
    func makeUIViewController(context: Context) -> ChatViewController {
        return ChatViewController(
            chatRoomId: chatRoomId,
            currentUser: currentUser,
            otherUser: otherUser,
            viewModel: viewModel,
            accentColor: accentUIColor
        )
    }
    
    func updateUIViewController(_ uiViewController: ChatViewController, context: Context) {
        // UI updates are handled within ChatViewController via polling or property observers
    }
}
