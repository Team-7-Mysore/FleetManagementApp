import Foundation
import Supabase
import Combine

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
            print("Fetching users...")
            let fetchedUsers: [AppUser] = try await supabase
                .from("users")
                .select()
                .neq("user_id", value: currentUserId)
                .execute()
                .value
            
            self.users = fetchedUsers
            self.applyFilter()
            
            print("Fetched users count:", fetchedUsers.count)
        } catch {
            print("Error fetching users: \(error)")
        }
    }
    
    // MARK: - Fetch Chat Rooms
    func fetchChatRooms(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // 1. Fetch participants and rooms
            let participants: [ChatParticipantWithRoom] = try await supabase
                .from("chat_participants")
                .select("chat_rooms(*)")
                .eq("user_id", value: userId)
                .execute()
                .value

            var rooms = participants.map { $0.chatRoom }
            
            // 2. Fetch last message for each room to determine visibility and preview
            let fortyEightHoursAgo = Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? Date()
            let isoFormatter = ISO8601DateFormatter()
            let dateString = isoFormatter.string(from: fortyEightHoursAgo)
            
            var filteredRooms: [ChatRoom] = []
            
            for var room in rooms {
                // Fetch the absolute latest message
                let lastMessages: [ChatMessage] = try await supabase
                    .from("chat_messages")
                    .select()
                    .eq("chat_room_id", value: room.id)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                
                if let lastMsg = lastMessages.first {
                    // Check if the message is within 48h
                    if let createdAt = lastMsg.createdAt, createdAt > fortyEightHoursAgo {
                        room.updatedAt = createdAt // Use message time for sorting
                        room.lastMessage = lastMsg.content
                        filteredRooms.append(room)
                    }
                } else {
                    // Room with no messages - show only if created recently (last 48h)
                    if let roomCreated = room.createdAt, roomCreated > fortyEightHoursAgo {
                        room.lastMessage = "No messages yet"
                        filteredRooms.append(room)
                    }
                }
            }

            self.chats = filteredRooms.sorted { ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast) }

        } catch {
            print("Error fetching chat rooms:", error)
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
        do {
            // 1. Fetch all room IDs where the current user is a participant
            let myParticipants: [ChatParticipant] = try await supabase
                .from("chat_participants")
                .select("chat_room_id")
                .eq("user_id", value: currentUserId)
                .execute()
                .value
            
            let myRoomIds = myParticipants.map { $0.chatRoomId }
            
            // 2. Check if any of these rooms also have the other user
            if !myRoomIds.isEmpty {
                let existingParticipants: [ChatParticipant] = try await supabase
                    .from("chat_participants")
                    .select("*, chat_rooms!inner(*)")
                    .in("chat_room_id", values: myRoomIds)
                    .eq("user_id", value: otherUserId)
                    .eq("chat_rooms.type", value: ChatRoomType.direct.rawValue)
                    .execute()
                    .value
                
                if let firstMatch = existingParticipants.first {
                    // Find the room object again to ensure we have it (already fetched with !inner)
                    // But for mapping simplicity, let's just fetch it once more or extract it
                    let room: ChatRoom = try await supabase
                        .from("chat_rooms")
                        .select()
                        .eq("id", value: firstMatch.chatRoomId)
                        .single()
                        .execute()
                        .value
                    return room
                }
            }
            
            // 3. If no room exists, create a new one
            let newRoomId = UUID()
            let newRoom = ChatRoom(
                id: newRoomId,
                type: .direct,
                name: nil, // Direct chats use participant names in UI
                workOrderId: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            _ = try await supabase
                .from("chat_rooms")
                .insert(newRoom)
                .execute()
            
            // 4. Add participants
            let participants: [ChatParticipant] = [
                ChatParticipant(chatRoomId: newRoomId, userId: currentUserId, joinedAt: Date(), lastReadAt: Date()),
                ChatParticipant(chatRoomId: newRoomId, userId: otherUserId, joinedAt: Date(), lastReadAt: Date())
            ]
            
            _ = try await supabase
                .from("chat_participants")
                .insert(participants)
                .execute()
            
            return newRoom
            
        } catch {
            print("Error in getOrCreateChatRoom: \(error)")
            return nil
        }
    }
}
