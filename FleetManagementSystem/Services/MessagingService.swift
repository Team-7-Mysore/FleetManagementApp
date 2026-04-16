import Foundation

// MARK: - Messaging Service
final class MessagingService {
    static let shared = MessagingService()
    private let store = MockDataStore.shared

    private init() {}

    func conversations(forUser userId: UUID) -> [Conversation] {
        // Group messages by the other participant
        let relevantMessages = store.messages.filter {
            $0.senderId == userId || $0.receiverId == userId
        }

        var grouped: [UUID: [Message]] = [:]
        for msg in relevantMessages {
            let otherId = msg.senderId == userId ? msg.receiverId : msg.senderId
            grouped[otherId, default: []].append(msg)
        }

        return grouped.compactMap { otherId, msgs in
            guard let otherUser = store.users.first(where: { $0.id == otherId }) else {
                return nil
            }
            let sorted = msgs.sorted { $0.timestamp > $1.timestamp }
            let unread = msgs.filter { !$0.isRead && $0.receiverId == userId }.count
            return Conversation(id: otherId, otherUser: otherUser,
                                lastMessage: sorted.first, unreadCount: unread)
        }.sorted { ($0.lastMessage?.timestamp ?? .distantPast) > ($1.lastMessage?.timestamp ?? .distantPast) }
    }

    func messages(between userId: UUID, and otherId: UUID) -> [Message] {
        store.messages.filter {
            ($0.senderId == userId && $0.receiverId == otherId) ||
            ($0.senderId == otherId && $0.receiverId == userId)
        }.sorted { $0.timestamp < $1.timestamp }
    }

    func sendMessage(from senderId: UUID, to receiverId: UUID, content: String) {
        let msg = Message(id: UUID(), senderId: senderId, receiverId: receiverId,
                          content: content, timestamp: Date(), isRead: false)
        store.messages.append(msg)
    }

    func markAsRead(messageId: UUID) {
        guard let idx = store.messages.firstIndex(where: { $0.id == messageId }) else { return }
        store.messages[idx].isRead = true
    }

    func unreadCount(forUser userId: UUID) -> Int {
        store.messages.filter { $0.receiverId == userId && !$0.isRead }.count
    }
}
