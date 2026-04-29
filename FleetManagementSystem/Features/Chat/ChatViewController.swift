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
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 🧼 iMessage Style Layout
        messagesCollectionView.backgroundColor = .systemBackground
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        
        // Fix for full-screen layout
        messagesCollectionView.contentInsetAdjustmentBehavior = .always
        messagesCollectionView.contentInset = .zero
        messagesCollectionView.scrollIndicatorInsets = .zero
        additionalSafeAreaInsets.bottom = 0
        
        setupInputBar()
        
        // ✅ Keyboard handling
        maintainPositionOnKeyboardFrameChanged = true
        scrollsToLastItemOnKeyboardBeginsEditing = true
        messagesCollectionView.keyboardDismissMode = .interactive
        
        // 💎 Refined iMessage dimensions & paddings
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.textMessageSizeCalculator.incomingAvatarSize = .zero
            layout.setMessageOutgoingAvatarSize(.zero)
            layout.setMessageIncomingAvatarSize(.zero)
            
            // Native-style message padding (sent = right-aligned, received = left-aligned)
            layout.setMessageIncomingMessagePadding(UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 50))
            layout.setMessageOutgoingMessagePadding(UIEdgeInsets(top: 4, left: 50, bottom: 4, right: 12))
            
            // Compact spacing between messages
            layout.setMessageIncomingMessageTopLabelAlignment(LabelAlignment(textAlignment: .left, textInsets: UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)))
            layout.setMessageOutgoingMessageTopLabelAlignment(LabelAlignment(textAlignment: .right, textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)))
        }
        
        // ✅ Dismiss keyboard on tap outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        messagesCollectionView.addGestureRecognizer(tapGesture)
        
        setupViewModelObservation()
        loadMessages()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Force inline display as requested
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.title = otherUser.displayName
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
        let mapped = newMessages.map { msg in
            let isCurrent = msg.senderId.uuidString == currentUser.senderId
            return MessageKitMessage(chatMessage: msg, senderName: isCurrent ? currentUser.displayName : otherUser.displayName)
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
    
    private func setupInputBar() {
        messageInputBar.delegate = self
        messageInputBar.backgroundView.backgroundColor = .systemBackground
        
        // Remove extra padding/margins
        messageInputBar.padding = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        messageInputBar.separatorLine.isHidden = false // Subtle line above input
        
        // Role-based accents in input bar
        messageInputBar.tintColor = accentColor
        messageInputBar.inputTextView.tintColor = accentColor
        messageInputBar.sendButton.setTitleColor(accentColor, for: .normal)
        messageInputBar.sendButton.setTitleColor(accentColor.withAlphaComponent(0.3), for: .disabled)
        
        // Improved input bar capsule look
        messageInputBar.inputTextView.backgroundColor = UIColor.systemGray6
        messageInputBar.inputTextView.layer.cornerRadius = 18
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    }
    
    private func loadMessages() {
        Task {
            await viewModel.fetchMessages(chatRoomId: chatRoomId)
        }
    }
}

// MARK: - MessagesDataSource
extension ChatViewController: MessagesDataSource {
    var currentSender: SenderType { return currentUser }
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int { return messages.count }
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
}

// MARK: - MessagesDisplayDelegate
extension ChatViewController: MessagesDisplayDelegate {
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? accentColor : UIColor.systemGray6
    }

    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .label
    }

    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
    }

    func cellBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        guard let status = receiptStatus(for: indexPath) else { return nil }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: status.color
        ]
        return NSAttributedString(string: status.text, attributes: attributes)
    }
}

// MARK: - MessagesLayoutDelegate & MessageCellDelegate
extension ChatViewController: MessagesLayoutDelegate, MessageCellDelegate {
    func cellBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return receiptStatus(for: indexPath) == nil ? 0 : 14
    }

    func cellBottomLabelAlignment(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> LabelAlignment? {
        guard receiptStatus(for: indexPath) != nil else { return nil }
        return LabelAlignment(textAlignment: .right, textInsets: UIEdgeInsets(top: 0, left: 0, bottom: 2, right: 10))
    }
}
