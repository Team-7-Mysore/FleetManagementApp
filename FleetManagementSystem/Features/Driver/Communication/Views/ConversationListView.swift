import SwiftUI

// MARK: - Conversation List View
struct ConversationListView: View {
    let user: User
    @StateObject private var vm: MessagingViewModel

    init(user: User) {
        self.user = user
        _vm = StateObject(wrappedValue: MessagingViewModel(user: user))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                if vm.conversations.isEmpty {
                    EmptyStateView(
                        icon: "message",
                        title: "No Messages",
                        message: "Your conversations will appear here."
                    )
                    .padding(.top, 60)
                } else {
                    ForEach(vm.conversations) { conversation in
                        NavigationLink {
                            ChatView(user: user, otherUser: conversation.otherUser)
                        } label: {
                            conversationRow(conversation)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("Messages")
        .onAppear { vm.loadConversations() }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: 14) {
            // Avatar
            Circle()
                .fill(roleColor(conversation.otherUser.role))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(conversation.otherUser.initials)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUser.fullName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    if let msg = conversation.lastMessage {
                        Text(msg.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack {
                    if let msg = conversation.lastMessage {
                        Text(msg.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(AppTheme.primaryGreen)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(14)
        .cardStyle()
        .padding(.vertical, 4)
    }

    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .fleetManager: return AppTheme.statusInfo
        case .driver:       return AppTheme.primaryGreen
        case .maintenance:  return AppTheme.statusWarning
        }
    }
}
