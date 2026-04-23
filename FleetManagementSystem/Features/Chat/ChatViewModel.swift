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
    @Published var currentMessage: String = ""
    @Published var searchText: String = "" {
        didSet { applyFilter() }
    }
    @Published var selectedRoleFilter: String = "All" {
        didSet { applyFilter() }
    }
    @Published var isLoading: Bool = false
    @Published var isCreatingRoom: Bool = false
    
    private let supabase = SupabaseManager.shared.client
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Debounce search if needed, but for now direct apply
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

            self.users = fetchedUsers.filter { $0.id != currentUserId }
            self.filteredUsers = self.users
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
                } else {
                    rooms[i].lastMessage = "No messages yet"
                }
            }

            // 5. Sort
            self.chats = rooms.sorted {
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
            result = result.filter { $0.role == roleValue }
        }
        
        // Search filter
        if !searchText.isEmpty {
            result = result.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        
        self.filteredUsers = result
    }
    
    // MARK: - Fetch Messages (with 48h limit)
    func fetchMessages(chatRoomId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        
        let fortyEightHoursAgo = Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? Date()
        let isoFormatter = ISO8601DateFormatter()
        let dateString = isoFormatter.string(from: fortyEightHoursAgo)
        
        do {
            let fetchedMessages: [ChatMessage] = try await supabase
                .from("chat_messages")
                .select()
                .eq("chat_room_id", value: chatRoomId)
                .gte("created_at", value: dateString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            self.messages = fetchedMessages
        } catch {
            print("Error fetching messages: \(error)")
        }
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
            
            // Re-fetch to update UI (polling or realtime would handle this normally)
            await fetchMessages(chatRoomId: chatRoomId)
        } catch {
            print("Error sending message: \(error)")
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
                .select("chat_room_id")
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
