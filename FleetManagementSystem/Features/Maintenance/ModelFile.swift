//
//  ModelFile.swift
//  FleetManagementSystem
//
//  Created by Dhaani on 16/04/26.
//

import Foundation

// MARK: - Work Order Enums
enum WorkOrderPriority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
}

enum WorkOrderStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

// MARK: - Chat Enums
enum ChatRoomType: String, Codable {
    case direct = "Direct"       // 1-on-1 chat
    case group = "Group"         // Standard group chat
    case workOrder = "WorkOrder" // Chat specifically tied to a repair job
}

enum MessageType: String, Codable {
    case text = "Text"
    case image = "Image"
    case system = "System"       // Auto-generated messages (e.g., "Status changed to Completed")
}

// MARK: - 1. Inventory Model
struct InventoryItem: Identifiable, Codable {
    let inventoryId: UUID
    var partName: String
    var vehicleCategory: String?
    var categoryDescription: String?
    var supplier: String?
    var quantity: Int
    var costPerUnit: Double?
    var sku: String?
    var location: String?
    var imageUrl: String?
    let createdAt: Date?
    var updatedAt: Date?
    
    // Satisfies Identifiable for SwiftUI
    var id: UUID { inventoryId }

    enum CodingKeys: String, CodingKey {
        case inventoryId = "inventory_id"
        case partName = "part_name"
        case vehicleCategory = "vehicle_category"
        case categoryDescription = "category_description"
        case supplier
        case quantity
        case costPerUnit = "cost_per_unit"
        case sku
        case location
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 2. Work Order Model
struct WorkOrder: Identifiable, Codable {
    let workOrderId: UUID
    var vehicleVin: String
    var vehicleName: String?
    var fleetUnitId: String?
    var priority: WorkOrderPriority
    var status: WorkOrderStatus
    var issueTitle: String
    var issueDescription: String?
    var hoursWorked: Double?
    var estCost: Double?
    var internalNotes: String?
    var maintenanceNotes: String?
    var images: [String]?
    let createdAt: Date?
    var updatedAt: Date?
    
    // Satisfies Identifiable for SwiftUI
    var id: UUID { workOrderId }

    enum CodingKeys: String, CodingKey {
        case workOrderId = "work_order_id"
        case vehicleVin = "vehicle_vin"
        case vehicleName = "vehicle_name"
        case fleetUnitId = "fleet_unit_id"
        case priority
        case status
        case issueTitle = "issue_title"
        case issueDescription = "issue_description"
        case hoursWorked = "hours_worked"
        case estCost = "est_cost"
        case internalNotes = "internal_notes"
        case maintenanceNotes = "maintenance_notes"
        case images
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 3. Work Order Task
struct WorkOrderTask: Identifiable, Codable {
    let taskId: UUID
    var workOrderId: UUID
    var description: String
    var isCompleted: Bool
    let createdAt: Date?
    
    // Satisfies Identifiable for SwiftUI
    var id: UUID { taskId }

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case workOrderId = "work_order_id"
        case description
        case isCompleted = "is_completed"
        case createdAt = "created_at"
    }
}

// MARK: - 4. Work Order Part
struct WorkOrderPart: Codable {
    // No Identifiable needed here as it's a junction table
    var workOrderId: UUID
    var inventoryId: UUID
    var quantityRequired: Int
    var costAtTime: Double?

    enum CodingKeys: String, CodingKey {
        case workOrderId = "work_order_id"
        case inventoryId = "inventory_id"
        case quantityRequired = "quantity_required"
        case costAtTime = "cost_at_time"
    }
}

// MARK: - 5. Chat Room
struct ChatRoom: Identifiable, Codable {
    let id: UUID
    var type: ChatRoomType
    var name: String?            // Optional: Name for group chats (e.g., "Mechanics Team")
    var workOrderId: UUID?       // Optional: Links the chat directly to a Work Order
    let createdAt: Date?
    var updatedAt: Date?         // Useful for sorting the inbox by "most recently active"
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case workOrderId = "work_order_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - 6. Chat Participant
// A junction table linking Users to Chat Rooms
struct ChatParticipant: Codable {
    var chatRoomId: UUID
    var userId: UUID             // Links to your auth.users or public.profiles table
    var joinedAt: Date?
    var lastReadAt: Date?        // Crucial for showing unread message badges/counts
    
    enum CodingKeys: String, CodingKey {
        case chatRoomId = "chat_room_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case lastReadAt = "last_read_at"
    }
}

// MARK: - 7. Chat Message
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    var chatRoomId: UUID
    var senderId: UUID           // The user who sent the message
    var messageType: MessageType
    var content: String?         // The text of the message (optional if it's just an image)
    var mediaUrl: String?        // Supabase Storage URL if they send a photo
    var isEdited: Bool?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case chatRoomId = "chat_room_id"
        case senderId = "sender_id"
        case messageType = "message_type"
        case content
        case mediaUrl = "media_url"
        case isEdited = "is_edited"
        case createdAt = "created_at"
    }
}
