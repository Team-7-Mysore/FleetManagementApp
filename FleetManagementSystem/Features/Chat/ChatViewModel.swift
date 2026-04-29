import Foundation
import Supabase
import Combine

struct ParticipantUserId: Codable {
    var userId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var chats: [ChatRoom] = []
    @Published var users: [AppUser] = []
    @Published var filteredUsers: [AppUser] = []
    @Published var messages: [ChatMessage] = []
    @Published var participantLastRead: [UUID: Date] = [:]
    @Published var currentMessage: String = ""
    @Published var searchText: String = "" {
        didSet { applyFilter() }
    }
    // Note: this patch introduces chat filtering logic (Part 1) and extends
    // existing user filtering behavior (Part 2 will use similar patterns).
    @Published var selectedRoleFilter: String = "All" {
        didSet { applyFilter() }
    }
    @Published var isLoading: Bool = false
    @Published var isCreatingRoom: Bool = false
    
    private let supabase = SupabaseManager.shared.client
    private var cancellables = Set<AnyCancellable>()
    private var roomsRealtimeChannel: RealtimeChannelV2?
    private var roomMessagesChannel: RealtimeChannelV2?
    private var participantsRealtimeChannel: RealtimeChannelV2?
    private var roomsRealtimeTask: Task<Void, Never>?
    private var roomMessagesTask: Task<Void, Never>?
    private var participantsRealtimeTask: Task<Void, Never>?
    private var activeChatRoomId: UUID?
    private var currentUserId: UUID?
    private var lastReadUpdateAt: [UUID: Date] = [:]
    
    // In-memory cache for messages: [RoomID: [Messages]]
    private var messageCache: [UUID: [ChatMessage]] = [:]
    
    init() {
        // Debounce search if needed, but for now direct apply
    }

    func setCurrentUserId(_ userId: UUID) {
        currentUserId = userId
    }

    // MARK: - Realtime Setup
    func startChatRoomsRealtime(userId: UUID) async {
        currentUserId = userId
        guard roomsRealtimeChannel == nil else { return }

        let channel = supabase.realtimeV2.channel("chat-rooms-\(userId.uuidString)")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "chat_messages"
        )

        roomsRealtimeChannel = channel

        do {
            try await channel.subscribeWithError()
        } catch {
            print("❌ Chat rooms realtime subscribe failed: \(error)")
            roomsRealtimeChannel = nil
            return
        }

        let decoder = Self.makeChatDecoder()
        roomsRealtimeTask?.cancel()
        roomsRealtimeTask = Task { [weak self] in
            guard let self = self else { return }
            for await action in changes {
                if Task.isCancelled { break }
                guard let message = self.decodeChatMessage(from: action, decoder: decoder) else { continue }
                await MainActor.run {
                    self.handleRoomsMessage(message)
                }
            }
        }
    }

    func stopChatRoomsRealtime() async {
        roomsRealtimeTask?.cancel()
        roomsRealtimeTask = nil
        if let channel = roomsRealtimeChannel {
            await channel.unsubscribe()
            roomsRealtimeChannel = nil
        }
    }

    func startChatRoomRealtime(chatRoomId: UUID) async {
        if activeChatRoomId == chatRoomId, roomMessagesChannel != nil { return }
        activeChatRoomId = chatRoomId

        roomMessagesTask?.cancel()
        roomMessagesTask = nil

        if let channel = roomMessagesChannel {
            await channel.unsubscribe()
            roomMessagesChannel = nil
        }

        let channel = supabase.realtimeV2.channel("chat-room-\(chatRoomId.uuidString)")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "chat_messages"
        )

        roomMessagesChannel = channel

        do {
            try await channel.subscribeWithError()
        } catch {
            print("❌ Chat room realtime subscribe failed: \(error)")
            roomMessagesChannel = nil
            return
        }

        let decoder = Self.makeChatDecoder()
        roomMessagesTask = Task { [weak self] in
            guard let self = self else { return }
            for await action in changes {
                if Task.isCancelled { break }
                guard let message = self.decodeChatMessage(from: action, decoder: decoder) else { continue }
                guard message.chatRoomId == chatRoomId else { continue }
                await MainActor.run {
                    self.applyIncomingMessage(message)
                }
            }
        }

        await refreshParticipants(chatRoomId: chatRoomId)
        await startChatParticipantsRealtime(chatRoomId: chatRoomId)
    }

    func stopChatRoomRealtime(chatRoomId: UUID) async {
        guard activeChatRoomId == chatRoomId else { return }
        roomMessagesTask?.cancel()
        roomMessagesTask = nil
        if let channel = roomMessagesChannel {
            await channel.unsubscribe()
            roomMessagesChannel = nil
        }
        participantsRealtimeTask?.cancel()
        participantsRealtimeTask = nil
        if let channel = participantsRealtimeChannel {
            await channel.unsubscribe()
            participantsRealtimeChannel = nil
        }
        activeChatRoomId = nil
    }

    private func startChatParticipantsRealtime(chatRoomId: UUID) async {
        if let channel = participantsRealtimeChannel {
            await channel.unsubscribe()
            participantsRealtimeChannel = nil
        }

        let channel = supabase.realtimeV2.channel("chat-room-participants-\(chatRoomId.uuidString)")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "chat_participants"
        )

        participantsRealtimeChannel = channel

        do {
            try await channel.subscribeWithError()
        } catch {
            print("❌ Chat participants realtime subscribe failed: \(error)")
            participantsRealtimeChannel = nil
            return
        }

        let decoder = Self.makeChatDecoder()
        participantsRealtimeTask?.cancel()
        participantsRealtimeTask = Task { [weak self] in
            guard let self = self else { return }
            for await action in changes {
                if Task.isCancelled { break }
                guard let participant = self.decodeChatParticipant(from: action, decoder: decoder) else { continue }
                guard participant.chatRoomId == chatRoomId else { continue }
                await MainActor.run {
                    self.participantLastRead[participant.userId] = participant.lastReadAt
                }
            }
        }
    }

    private func handleRoomsMessage(_ message: ChatMessage) {
        if chats.contains(where: { $0.id == message.chatRoomId }) {
            applyIncomingMessage(message)
            return
        }

        guard let userId = currentUserId else { return }
        Task {
            await fetchChatRooms(userId: userId)
        }
    }

    private func applyIncomingMessage(_ message: ChatMessage) {
        var cached = messageCache[message.chatRoomId] ?? []

        if let index = cached.firstIndex(where: { $0.id == message.id }) {
            cached[index] = message
        } else {
            cached.append(message)
        }

        cached.sort {
            ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
        }

        messageCache[message.chatRoomId] = cached

        if activeChatRoomId == message.chatRoomId {
            messages = cached
            if let userId = currentUserId, message.senderId != userId {
                let readAt = message.createdAt ?? Date()
                Task {
                    await markChatRead(chatRoomId: message.chatRoomId, userId: userId, readAt: readAt)
                }
            }
        }

        updateChatPreview(chatRoomId: message.chatRoomId, message: message)
    }

    private func updateChatPreview(chatRoomId: UUID, message: ChatMessage) {
        guard let index = chats.firstIndex(where: { $0.id == chatRoomId }) else { return }

        let preview = previewText(for: message)
        if let preview = preview {
            chats[index].lastMessage = preview
        }

        chats[index].updatedAt = message.createdAt ?? Date()
        chats.sort {
            ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast)
        }
    }

    private func previewText(for message: ChatMessage) -> String? {
        let trimmed = message.content?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed = trimmed, !trimmed.isEmpty { return trimmed }

        switch message.messageType {
        case .image:
            return "Photo"
        case .system:
            return "System message"
        default:
            return nil
        }
    }

    private func decodeChatMessage(from action: AnyAction, decoder: JSONDecoder) -> ChatMessage? {
        switch action {
        case .insert(let action):
            return try? action.decodeRecord(as: ChatMessage.self, decoder: decoder)
        case .update(let action):
            return try? action.decodeRecord(as: ChatMessage.self, decoder: decoder)
        default:
            return nil
        }
    }

    private func decodeChatParticipant(from action: AnyAction, decoder: JSONDecoder) -> ChatParticipantReadRecord? {
        switch action {
        case .insert(let action):
            return try? action.decodeRecord(as: ChatParticipantReadRecord.self, decoder: decoder)
        case .update(let action):
            return try? action.decodeRecord(as: ChatParticipantReadRecord.self, decoder: decoder)
        default:
            return nil
        }
    }

    private static func makeChatDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = BackendDateParser.parse(raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(raw)"
            )
        }
        return decoder
    }
    
    // MARK: - Fetch Users
    func fetchUsers(currentUserId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedUsers: [AppUser] = try await supabase
                .from("users")
                .select()
                .execute()
                .value

            self.users = fetchedUsers
            self.filteredUsers = fetchedUsers.filter { $0.id != currentUserId }
        } catch {
            print("❌ Error fetching users: \(error)")
        }
    }
    
    // MARK: - Fetch Chat Rooms
    func fetchChatRooms(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Get all rooms where current user is a participant
            let participants: [ChatParticipantWithRoom] = try await supabase
                .from("chat_participants")
                .select("chat_rooms(*)")
                .eq("user_id", value: userId)
                .execute()
                .value

            var rooms = participants.map { $0.chatRoom }

            guard !rooms.isEmpty else {
                self.chats = []
                return
            }

            let roomIds = rooms.map { $0.id }

            // 2. Fetch ALL participants for ALL rooms (single query)
            let allParticipants: [ParticipantUserIdWithRoom] = try await supabase
                .from("chat_participants")
                .select("chat_room_id, user_id")
                .in("chat_room_id", values: roomIds)
                .execute()
                .value

            // Map roomId → participants
            let participantsMap = Dictionary(grouping: allParticipants, by: { $0.chatRoomId })

            // 3. Fetch ALL last messages (single query)
            let messages: [ChatMessage] = try await supabase
                .from("chat_messages")
                .select()
                .in("chat_room_id", values: roomIds)
                .order("created_at", ascending: false)
                .execute()
                .value

            // Map roomId → latest message
            let messageMap = Dictionary(grouping: messages, by: { $0.chatRoomId })

            // 4. Attach data
            for i in 0..<rooms.count {
                let roomId = rooms[i].id

                // participants
                rooms[i].participantIds = participantsMap[roomId]?.map { $0.userId } ?? []

                // latest message
                if let latest = messageMap[roomId]?.first {
                    rooms[i].updatedAt = latest.createdAt
                    rooms[i].lastMessage = latest.content
                }
            }

            // 5. Filter & Sort (48-hour strict policy)
            let fortyEightHoursAgo = Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? Date()
            
            self.chats = rooms.filter { room in
                guard let updatedAt = room.updatedAt else { return false }
                return updatedAt > fortyEightHoursAgo
            }.sorted {
                ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast)
            }

        } catch {
            print("❌ Error fetching chat rooms:", error)
        }
    }
    
    // MARK: - Filter Logic
    private func applyFilter() {
        var result = users
        
        // Role filter
        if selectedRoleFilter != "All" {
            let roleValue = selectedRoleFilter.lowercased().replacingOccurrences(of: " ", with: "_")
            result = result.filter { $0.role.lowercased() == roleValue }
        }
        
        // Search filter
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(lower) || $0.email.lowercased().contains(lower) }
        }
        
        self.filteredUsers = result
    }

    // MARK: - Part 1: Filter Chats
    func filteredChats(for currentUserId: UUID) -> [ChatRoom] {
        var result = chats

        // Search by chat name OR last message
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            result = result.filter { room in
                let nameMatch = (room.name ?? "").lowercased().contains(lower)
                let messageMatch = (room.lastMessage ?? "").lowercased().contains(lower)
                return nameMatch || messageMatch
            }
        }

        return result
    }
    
    // MARK: - Fetch Messages (with 48h limit + Cache)
    func fetchMessages(chatRoomId: UUID) async {
        activeChatRoomId = chatRoomId
        // ⚡ LOAD FROM CACHE FIRST (INSTANT UI)
        if let cached = messageCache[chatRoomId] {
            self.messages = cached
        }
        
        // Don't show loading spinner if we have cached data for smoother UX
        if messageCache[chatRoomId] == nil {
            isLoading = true
        }
        
        defer { isLoading = false }
        
        let fortyEightHoursAgo = Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? Date()
        let isoFormatter = ISO8601DateFormatter()
        let dateString = isoFormatter.string(from: fortyEightHoursAgo)
        
        do {
            let response = try await supabase
                .from("chat_messages")
                .select()
                .eq("chat_room_id", value: chatRoomId)
                .gte("created_at", value: dateString)
                .order("created_at", ascending: true)
                .execute()

            let decoder = Self.makeChatDecoder()
            let fetchedMessages = try decoder.decode([ChatMessage].self, from: response.data)
            
            // UPDATE CACHE & UI
            self.messageCache[chatRoomId] = fetchedMessages
            self.messages = fetchedMessages
            updateChatPreviewFromCache(chatRoomId: chatRoomId)
        } catch let error as PostgrestError {
            print("❌ Database Error fetching messages: \(error.message)")
        } catch {
            print("❌ General Error fetching messages: \(error)")
        }
    }

    func refreshParticipants(chatRoomId: UUID) async {
        do {
            let response = try await supabase
                .from("chat_participants")
                .select("chat_room_id, user_id, last_read_at")
                .eq("chat_room_id", value: chatRoomId)
                .execute()

            let decoder = Self.makeChatDecoder()
            let records = try decoder.decode([ChatParticipantReadRecord].self, from: response.data)
            var map: [UUID: Date] = [:]
            for record in records {
                if let lastReadAt = record.lastReadAt {
                    map[record.userId] = lastReadAt
                }
            }
            participantLastRead.merge(map) { _, new in new }
        } catch {
            print("❌ Failed to refresh chat participants: \(error)")
        }
    }

    func markChatRead(chatRoomId: UUID, userId: UUID, readAt: Date) async {
        let currentRead = participantLastRead[userId] ?? .distantPast
        if readAt <= currentRead { return }

        let now = Date()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateString = formatter.string(from: readAt)

        do {
            _ = try await supabase
                .from("chat_participants")
                .update(["last_read_at": dateString])
                .eq("chat_room_id", value: chatRoomId)
                .eq("user_id", value: userId)
                .execute()

            participantLastRead[userId] = readAt
            lastReadUpdateAt[chatRoomId] = now
        } catch {
            print("❌ Failed to update read receipt: \(error)")
        }
    }

    private func updateChatPreviewFromCache(chatRoomId: UUID) {
        guard let cached = messageCache[chatRoomId], let last = cached.last else { return }
        updateChatPreview(chatRoomId: chatRoomId, message: last)
    }
    

    
    // MARK: - Send Message
    func sendMessage(chatRoomId: UUID, senderId: UUID, content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        do {
            let insertData: [String: AnyJSON] = [
                "chat_room_id": .string(chatRoomId.uuidString),
                "sender_id": .string(senderId.uuidString),
                "message_type": .string("Text"),
                "content": .string(content)
            ]
            
            _ = try await supabase
                .from("chat_messages")
                .insert(insertData)
                .execute()
            
            // 🔥 Refresh messages to update UI with the new message and timestamp
            await fetchMessages(chatRoomId: chatRoomId)
        } catch let error as PostgrestError {
            print("❌ Database Error sending message: \(error.message)")
        } catch {
            print("❌ General Error sending message: \(error)")
        }
    }
    
    // MARK: - Chat Room Creation / Fetching
    func getOrCreateChatRoom(currentUserId: UUID, otherUserId: UUID) async -> ChatRoom? {
        guard !isCreatingRoom else { return nil }
        isCreatingRoom = true
        defer { isCreatingRoom = false }

        print("📱 getOrCreateChatRoom: currentUserId=\(currentUserId), otherUserId=\(otherUserId)")

        guard currentUserId != otherUserId else {
            print("❌ Cannot chat with yourself")
            return nil
        }

        do {
            // 🔥 STEP 1: GET ALL ROOMS OF CURRENT USER
            let myRooms: [ChatParticipant] = try await supabase
                .from("chat_participants")
                .select("chat_room_id, user_id")
                .eq("user_id", value: currentUserId)
                .execute()
                .value

            let roomIds = myRooms.map { $0.chatRoomId }
            print("📱 Found \(roomIds.count) rooms")

            // 🔥 STEP 2: CHECK IF OTHER USER IS IN SAME ROOM
            if !roomIds.isEmpty {
                let matches: [ChatParticipant] = try await supabase
                    .from("chat_participants")
                    .select("chat_room_id")
                    .in("chat_room_id", values: roomIds)
                    .eq("user_id", value: otherUserId)
                    .execute()
                    .value

                if let match = matches.first {
                    print("✅ Reusing existing room:", match.chatRoomId)

                    return try await fetchChatRoom(
                        roomId: match.chatRoomId,
                        participantIds: [currentUserId, otherUserId]
                    )
                }
            }

            // 🔥 STEP 3: CREATE NEW ROOM (ONLY IF NOT FOUND)
            let newRoomId = UUID()
            print("📱 Creating new room:", newRoomId)

            let insertRoom: [String: AnyJSON] = [
                "id": .string(newRoomId.uuidString),
                "type": .string(ChatRoomType.direct.rawValue),
                "name": .null,
                "work_order_id": .null
            ]

            _ = try await supabase
                .from("chat_rooms")
                .insert(insertRoom)
                .execute()

            // 🔥 STEP 4: ADD PARTICIPANTS
            let now = ISO8601DateFormatter().string(from: Date())

            let participants: [[String: AnyJSON]] = [
                [
                    "chat_room_id": .string(newRoomId.uuidString),
                    "user_id": .string(currentUserId.uuidString),
                    "joined_at": .string(now),
                    "last_read_at": .string(now)
                ],
                [
                    "chat_room_id": .string(newRoomId.uuidString),
                    "user_id": .string(otherUserId.uuidString),
                    "joined_at": .string(now),
                    "last_read_at": .string(now)
                ]
            ]

            _ = try await supabase
                .from("chat_participants")
                .insert(participants)
                .execute()

            print("📱 Room + participants created")

            // 🔥 STEP 5: RETURN ROOM (SAFE)
            return try await fetchChatRoom(
                roomId: newRoomId,
                participantIds: [currentUserId, otherUserId]
            )

        } catch {
            print("❌ Error in getOrCreateChatRoom:", error)
            return nil
        }
    }

    private func ensureUserExists(userId: UUID, email: String) async throws {
        let existing: [AppUser] = try await supabase
            .from("users")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        if existing.isEmpty {
            print("⚠️ Creating missing user in DB")

            let safeEmail = email.isEmpty ? "\(userId.uuidString.lowercased())@placeholder.local" : email
            let fallbackName = safeEmail.split(separator: "@").first.map(String.init).flatMap { $0.isEmpty ? nil : $0 } ?? "User"

            let newUser: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "email": .string(safeEmail),
                "name": .string(fallbackName),
                "role": .string(AppUserRole.driver.rawValue)
            ]

            try await supabase
                .from("users")
                .insert(newUser)
                .execute()
        }
    }

    private func fetchChatRoom(roomId: UUID, participantIds: [UUID]) async throws -> ChatRoom {
        let rooms: [ChatRoom] = try await supabase
            .from("chat_rooms")
            .select()
            .eq("id", value: roomId)
            .limit(1)
            .execute()
            .value
            
        guard var room = rooms.first else {
            throw URLError(.badServerResponse)
        }

        room.participantIds = participantIds
        return room
    }
}

private struct ChatParticipantReadRecord: Codable {
    let chatRoomId: UUID
    let userId: UUID
    let lastReadAt: Date?

    enum CodingKeys: String, CodingKey {
        case chatRoomId = "chat_room_id"
        case userId = "user_id"
        case lastReadAt = "last_read_at"
    }
}
