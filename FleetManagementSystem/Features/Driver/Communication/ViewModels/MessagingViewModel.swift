import Foundation
import Combine

// MARK: - Messaging ViewModel
@MainActor
final class MessagingViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var messages: [Message] = []
    @Published var messageText = ""

    private let user: User
    private let service = MessagingService.shared

    init(user: User) {
        self.user = user
    }

    func loadConversations() {
        conversations = service.conversations(forUser: user.id)
    }

    func loadMessages(with otherId: UUID) {
        messages = service.messages(between: user.id, and: otherId)
        // Mark unread messages as read
        for msg in messages where !msg.isRead && msg.receiverId == user.id {
            service.markAsRead(messageId: msg.id)
        }
    }

    func sendMessage(to receiverId: UUID) {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        service.sendMessage(from: user.id, to: receiverId, content: trimmed)
        messageText = ""
        loadMessages(with: receiverId)
        loadConversations()
    }

    var totalUnread: Int {
        service.unreadCount(forUser: user.id)
    }
}
