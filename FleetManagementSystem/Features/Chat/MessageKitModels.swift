import MessageKit
import Foundation

struct Sender: SenderType {
    let senderId: String
    let displayName: String
}

struct MessageKitMessage: MessageKit.MessageType {
    let sender: SenderType
    let messageId: String
    let sentDate: Date
    let kind: MessageKind

    init(chatMessage: ChatMessage, senderName: String) {
        self.sender = Sender(
            senderId: chatMessage.senderId.uuidString,
            displayName: senderName
        )
        self.messageId = chatMessage.id.uuidString
        self.sentDate = chatMessage.createdAt ?? Date()
        self.kind = .text(chatMessage.content ?? "")
    }
}
