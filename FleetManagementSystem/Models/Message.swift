import Foundation

// MARK: - Message
struct Message: Identifiable, Codable {
    let id: UUID
    var senderId: UUID
    var receiverId: UUID
    var content: String
    var timestamp: Date
    var isRead: Bool

    func isSentBy(_ userId: UUID) -> Bool {
        senderId == userId
    }
}

// MARK: - Conversation
struct Conversation: Identifiable {
    let id: UUID
    let otherUser: User
    let lastMessage: Message?
    let unreadCount: Int
}
