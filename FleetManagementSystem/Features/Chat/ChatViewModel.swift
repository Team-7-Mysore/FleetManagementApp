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
            let fetchedUsers: [AppUser] = try await supabase
                .from("users")
                .select()
                .neq("id", value: currentUserId)
                .execute()
                .value
            
            self.users = fetchedUsers
            self.applyFilter()
        } catch {
            print("Error fetching users: \(error)")
        }
    }
    
    // MARK: - Fetch Chat Rooms
    func fetchChatRooms(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let participants: [ChatParticipantWithRoom] = try await supabase
                .from("chat_participants")
                .select("chat_rooms(*)")
                .eq("user_id", value: userId)
                .execute()
                .value

            self.chats = participants.map { $0.chatRoom }

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
            // Check if direct chat already exists between these two
            // This usually requires a complex query or a specific schema.
            // For simplicity, we check participants.
            
            let query = """
            select chat_room_id from chat_participants 
            where user_id in ('\(currentUserId.uuidString)', '\(otherUserId.uuidString)')
            group by chat_room_id
            having count(chat_room_id) = 2
            """
            
            // Note: Direct SQL might be better via RPC, but let's try a simpler approach
            // or assume we create a new one if not found in local 'chats' cache for simplicity.
            
            // Creating a new room
            let newRoomId = UUID()
            let newRoom: [String: AnyJSON] = [
                "id": .string(newRoomId.uuidString),
                "type": .string("Direct")
            ]
            
            _ = try await supabase.from("chat_rooms").insert(newRoom).execute()
            
            let participants: [[String: AnyJSON]] = [
                ["chat_room_id": .string(newRoomId.uuidString), "user_id": .string(currentUserId.uuidString)],
                ["chat_room_id": .string(newRoomId.uuidString), "user_id": .string(otherUserId.uuidString)]
            ]
            
            _ = try await supabase.from("chat_participants").insert(participants).execute()
            
            return ChatRoom(id: newRoomId, type: .direct, name: nil, workOrderId: nil, createdAt: Date(), updatedAt: Date())
            
        } catch {
            print("Error in getOrCreateChatRoom: \(error)")
            return nil
        }
    }
}
