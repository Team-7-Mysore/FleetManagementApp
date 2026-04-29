import UIKit
import MessageKit
import InputBarAccessoryView
import Combine

class ChatViewController: MessagesViewController {

    var chatRoomId: UUID
    var currentUser: Sender
    var otherUser: Sender
    var viewModel: ChatViewModel

    private var messages: [MessageKitMessage] = []
    private var cancellables = Set<AnyCancellable>()
    private let accentColor: UIColor

    // Disable MessageKit's inputAccessoryView — SwiftUI handles the input bar
    override var inputAccessoryView: UIView? { return nil }
    override var canBecomeFirstResponder: Bool { return false }

    init(chatRoomId: UUID, currentUser: Sender, otherUser: Sender, viewModel: ChatViewModel, accentColor: UIColor) {
        self.chatRoomId = chatRoomId
        self.currentUser = currentUser
        self.otherUser = otherUser
        self.viewModel = viewModel
        self.accentColor = accentColor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()

        // Disable MessageKit's keyboard handling — SwiftUI manages the input bar
        maintainPositionOnKeyboardFrameChanged = false
        scrollsToLastItemOnKeyboardBeginsEditing = false
        additionalBottomInset = 0

        // Hide the built-in MessageKit input bar
        messageInputBar.isHidden = true

        // Hide avatars for iMessage feel
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            layout.setMessageOutgoingAvatarSize(.zero)
            layout.setMessageIncomingAvatarSize(.zero)
        }

        // Dismiss keyboard on tap
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        messagesCollectionView.addGestureRecognizer(tapGesture)

        setupViewModelObservation()
        loadMessages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Task { await viewModel.startChatRoomRealtime(chatRoomId: chatRoomId) }
    }



    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.clearMessages()
    }

    private func setupViewModelObservation() {
        viewModel.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msgs in
                self?.updateMessages(msgs)
            }
            .store(in: &cancellables)

        viewModel.$participantLastRead
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.messagesCollectionView.reloadData()
            }
            .store(in: &cancellables)
    }

    private func updateMessages(_ newMessages: [ChatMessage]) {
        let roomMessages = newMessages.filter { $0.chatRoomId == self.chatRoomId }
        let mapped = roomMessages.map { msg in
            let isCurrent = msg.senderId.uuidString == currentUser.senderId
            let content = msg.content ?? ""
            
            // Format time
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            let timeString = timeFormatter.string(from: msg.createdAt ?? Date())
            
            // Font and Colors
            let mainFont = UIFont.systemFont(ofSize: 16)
            let mainColor = isCurrent ? UIColor.white : UIColor.label
            let metaFont = UIFont.systemFont(ofSize: 11)
            let metaColor = isCurrent ? UIColor.white.withAlphaComponent(0.7) : UIColor.secondaryLabel
            
            // Add non-breaking spaces for spacing between text and timestamp
            let attributedString = NSMutableAttributedString(string: content + "\u{00A0}\u{00A0}\u{00A0}", attributes: [
                .font: mainFont,
                .foregroundColor: mainColor
            ])
            
            // Build metadata string (time + ticks)
            var metaText = timeString
            if isCurrent {
                var isRead = false
                if let otherId = UUID(uuidString: otherUser.senderId),
                   let lastReadAt = viewModel.participantLastRead[otherId],
                   let messageDate = msg.createdAt {
                    isRead = lastReadAt >= messageDate
                }
                // ✓ is \u{2713}
                metaText += isRead ? " \u{2713}\u{2713}" : " \u{2713}"
            }
            
            let metaString = NSAttributedString(string: metaText, attributes: [
                .font: metaFont,
                .foregroundColor: metaColor
            ])
            
            attributedString.append(metaString)
            
            return MessageKitMessage(chatMessage: msg, senderName: isCurrent ? currentUser.displayName : otherUser.displayName, customKind: .attributedText(attributedString))
        }
        self.messages = mapped
        messagesCollectionView.reloadData()
        messagesCollectionView.scrollToLastItem(animated: true)
        if !messages.isEmpty {
            messagesCollectionView.reloadSections(IndexSet(integer: messages.count - 1))
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func setupCollectionView() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
    }



    private func loadMessages() {
        Task {
            await viewModel.fetchMessages(chatRoomId: chatRoomId)
        }
    }
}

// MARK: - MessagesDataSource
extension ChatViewController: MessagesDataSource {

    var currentSender: SenderType {
        return currentUser
    }

    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }

    func messageForItem(at indexPath: IndexPath,
                        in messagesCollectionView: MessagesCollectionView) -> MessageKit.MessageType {
        return messages[indexPath.section]
    }

    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        if isFirstMessageInDay(at: indexPath) {
            let date = message.sentDate
            let text = formatDateHeader(date)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle
            ]
            return NSAttributedString(string: text, attributes: attributes)
        }
        return nil
    }

    private func isFirstMessageInDay(at indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 { return true }
        let currentItem = messages[indexPath.section]
        let previousItem = messages[indexPath.section - 1]
        
        return !Calendar.current.isDate(currentItem.sentDate, inSameDayAs: previousItem.sentDate)
    }

    private func formatDateHeader(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}



// MARK: - MessagesDisplayDelegate
extension ChatViewController: MessagesDisplayDelegate {
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message)
            ? accentColor
            : UIColor.systemGray5
    }

    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .label
    }

    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
    }
}

// MARK: - MessagesLayoutDelegate & MessageCellDelegate
extension ChatViewController: MessagesLayoutDelegate, MessageCellDelegate {
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return isFirstMessageInDay(at: indexPath) ? 36 : 0
    }
}
