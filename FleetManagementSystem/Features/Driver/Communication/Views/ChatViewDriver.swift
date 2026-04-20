import SwiftUI

// MARK: - Chat View
struct ChatViewDriver: View {
    let user: User
    let otherUser: User
    @StateObject private var vm: MessagingViewModel
    @FocusState private var isInputFocused: Bool

    init(user: User, otherUser: User) {
        self.user = user
        self.otherUser = otherUser
        _vm = StateObject(wrappedValue: MessagingViewModel(user: user))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .onChange(of: vm.messages.count) {
                    if let lastId = vm.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 10) {
                TextField("Type a message...", text: $vm.messageText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .focused($isInputFocused)

                Button {
                    vm.sendMessage(to: otherUser.id)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color(.systemGray3)
                            : AppTheme.primaryGreen
                        )
                }
                .disabled(vm.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .navigationTitle(otherUser.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: otherUser.role.systemImage)
                        .font(.caption)
                    Text(otherUser.role.rawValue)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            vm.loadMessages(with: otherUser.id)
        }
    }

    // MARK: - Message Bubble
    private func messageBubble(_ message: Message) -> some View {
        let isSent = message.isSentBy(user.id)

        return HStack {
            if isSent { Spacer(minLength: 60) }

            VStack(alignment: isSent ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(isSent ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isSent
                        ? AnyShapeStyle(AppTheme.primaryGreen)
                        : AnyShapeStyle(Color(.tertiarySystemGroupedBackground))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if !isSent { Spacer(minLength: 60) }
        }
    }
}
