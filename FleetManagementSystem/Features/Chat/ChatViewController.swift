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
        setupInputBar()
        
        // ✅ Keyboard handling — let MessageKit manage input bar position
        maintainPositionOnKeyboardFrameChanged = true
        scrollsToLastItemOnKeyboardBeginsEditing = true
        additionalBottomInset = 0
        messagesCollectionView.keyboardDismissMode = .interactive
        
        // Hide avatars for iMessage feel
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
            layout.textMessageSizeCalculator.outgoingAvatarSize = .zero
            layout.textMessageSizeCalculator.incomingAvatarSize = .zero
        }
        
        // ✅ Dismiss keyboard on tap outside input bar
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        messagesCollectionView.addGestureRecognizer(tapGesture)
        
        // Input bar styling
        messageInputBar.backgroundView.backgroundColor = .systemBackground
        
        setupViewModelObservation()
        loadMessages()
    }
    
    private func setupViewModelObservation() {
        viewModel.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msgs in
                self?.updateMessages(msgs)
            }
            .store(in: &cancellables)
    }
    
    private func updateMessages(_ newMessages: [ChatMessage]) {
        self.messages = newMessages.map { msg in
            let isCurrent = msg.senderId.uuidString == currentUser.senderId
            return MessageKitMessage(chatMessage: msg, senderName: isCurrent ? currentUser.displayName : otherUser.displayName)
        }
        messagesCollectionView.reloadData()
        messagesCollectionView.scrollToLastItem(animated: true)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    private func setupCollectionView() {
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
    }
    
    private func setupInputBar() {
        messageInputBar.delegate = self
        messageInputBar.sendButton.setTitleColor(accentColor, for: .normal)
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
extension ChatViewController: MessagesLayoutDelegate, MessageCellDelegate {}

// MARK: - InputBarAccessoryViewDelegate
extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        inputBar.inputTextView.text = ""
        
        Task {
            let senderUUID = UUID(uuidString: currentUser.senderId) ?? UUID()
            await viewModel.sendMessage(chatRoomId: chatRoomId, senderId: senderUUID, content: content)
            loadMessages()
        }
    }
}
