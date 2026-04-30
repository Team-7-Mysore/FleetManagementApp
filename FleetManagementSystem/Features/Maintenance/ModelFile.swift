//
//  ModelFile.swift
//  FleetManagementSystem
//
//  Created by Dhaani on 16/04/26.
//

import Foundation
import SwiftUI // Added this so we can use Color

// MARK: - App User
struct AppUser: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
    var role: String // fleet_manager, maintenance, driver
    var avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case name
        case email
        case role
        case avatarUrl = "avatar_url"
    }
}

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

// MARK: - Vehicle Type Enum
enum VehicleType: String, Codable, CaseIterable {
    case bike = "Bike"
    case car = "Car"
    case bus = "Bus"
    case truck = "Truck"

    var sfSymbol: String {
        switch self {
        case .bike: return "motorcycle"
        case .car: return "car.fill"
        case .bus: return "bus.fill"
        case .truck: return "box.truck.fill"
        }
    }

    var color: Color {
        switch self {
        case .bike: return Color(hex: "#2C2C2E")
        case .car: return Color(hex: "#0A84FF")
        case .bus: return Color(hex: "#2E7D32")
        case .truck: return Color(hex: "#C75C1A")
        }
    }
}

// MARK: - Chat Enums
enum ChatRoomType: String, Codable {
    case direct = "Direct"       // 1-on-1 chat
    case group = "Group"         // Standard group chat
    case workOrder = "WorkOrder" // Chat specifically tied to a repair job
}

enum ChatMessageType: String, Codable {
    case text = "Text"
    case image = "Image"
    case system = "System"
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

    var vehicleId: UUID
    var maintenancePersonnelId: UUID?
    var vehicle: WorkOrderVehicle?
    

    var priority: WorkOrderPriority
    var status: WorkOrderStatus
    var isApproved: Bool
    var issueTitle: String
    var issueDescription: String?
    var hoursWorked: Double?
    var estCost: Double?
    var internalNotes: String?
    var maintenanceNotes: String?
    var images: [String]?
    let createdAt: Date?
    var updatedAt: Date?
    
    var id: UUID { workOrderId }
    
    enum CodingKeys: String, CodingKey {
        case workOrderId = "work_order_id"
        case vehicleId = "vehicle_id"
        case maintenancePersonnelId = "maintenance_personnel_id"
        case vehicle = "vehicles"
        case priority
        case status
        case isApproved = "is_approved"
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
  
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(workOrderId, forKey: .workOrderId)
        try container.encode(vehicleId, forKey: .vehicleId)
        try container.encodeIfPresent(maintenancePersonnelId, forKey: .maintenancePersonnelId)
        try container.encode(priority, forKey: .priority)
        try container.encode(status, forKey: .status)
        try container.encode(isApproved, forKey: .isApproved)
        try container.encode(issueTitle, forKey: .issueTitle)
        try container.encodeIfPresent(issueDescription, forKey: .issueDescription)
        try container.encodeIfPresent(hoursWorked, forKey: .hoursWorked)
        try container.encodeIfPresent(estCost, forKey: .estCost)
        try container.encodeIfPresent(internalNotes, forKey: .internalNotes)
        try container.encodeIfPresent(maintenanceNotes, forKey: .maintenanceNotes)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
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
    var createdAt: Date?
    var usedAt: Date?

    enum CodingKeys: String, CodingKey {
        case workOrderId = "work_order_id"
        case inventoryId = "inventory_id"
        case quantityRequired = "quantity_required"
        case costAtTime = "cost_at_time"
        case createdAt = "created_at"
        case usedAt = "used_at"
    }
}

// MARK: - Helper Struct for Joined Vehicle Data
struct WorkOrderVehicle: Codable {
    let vehicleId: UUID
    let vin: String?
    let numberPlate: String?
    let vehicleName: String?
    let vehicleType: VehicleType?

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case vin
        case numberPlate = "number_plate"
        case vehicleName = "vehicle_name"
        case vehicleType = "vehicle_type"
    }

    init(
        vehicleId: UUID,
        vin: String?,
        numberPlate: String?,
        vehicleName: String?,
        vehicleType: VehicleType?
    ) {
        self.vehicleId = vehicleId
        self.vin = vin
        self.numberPlate = numberPlate
        self.vehicleName = vehicleName
        self.vehicleType = vehicleType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        vehicleId = try container.decode(UUID.self, forKey: .vehicleId)
        vin = try container.decodeIfPresent(String.self, forKey: .vin)
        numberPlate = try container.decodeIfPresent(String.self, forKey: .numberPlate)
        vehicleName = try container.decodeIfPresent(String.self, forKey: .vehicleName)

        let rawVehicleType = try container.decodeIfPresent(String.self, forKey: .vehicleType)
        vehicleType = VehicleType(rawValue: rawVehicleType ?? "")
            ?? VehicleType(rawValue: rawVehicleType?.capitalized ?? "")
    }
}

// MARK: - Work Order Report
struct WorkOrderReportRecord: Codable, Identifiable {
    var id: UUID?
    var workOrderId: UUID
    var reportUrl: String
    var reportName: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "report_id"
        case workOrderId = "work_order_id"
        case reportUrl = "report_url"
        case reportName = "report_name"
    }
}


// MARK: - 5. Chat Room
struct ChatRoom: Identifiable, Codable, Hashable {
    let id: UUID
    var type: ChatRoomType
    var name: String?            // Optional: Name for group chats (e.g., "Mechanics Team")
    var workOrderId: UUID?       // Optional: Links the chat directly to a Work Order
    let createdAt: Date?
    var updatedAt: Date?         // Useful for sorting the inbox by "most recently active"
    var lastMessage: String?     // Local property for inbox preview
    var participantIds: [UUID] = []  // Local property for participant IDs

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
    var senderId: UUID
    var messageType: ChatMessageType
    var content: String?
    var mediaUrl: String?
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

struct ChatPreview: Identifiable {
    let id: UUID
    let name: String
    let lastMessage: String
    let timestamp: Date
    let unreadCount: Int
}

struct SendMessageRequest {
    let chatRoomId: UUID
    let senderId: UUID
    let content: String
}

struct ChatParticipantWithRoom: Codable {
    let chatRoom: ChatRoom

    enum CodingKeys: String, CodingKey {
        case chatRoom = "chat_rooms"
    }
}

extension Color {
    static let TechBlue = Color(red: 0/255, green: 89/255, blue: 184/255)
}


struct ParticipantUserIdWithRoom: Codable {
    let chatRoomId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case chatRoomId = "chat_room_id"
        case userId = "user_id"
    }
}

// MARK: - Driver Report Models
enum DriverReportCategory: String, Codable, CaseIterable {
    case mechanical = "mechanical"
    case electrical = "electrical"
    case tyreWheel = "tyre/wheel"
    case fluidLeak = "fluid leak"
    case bodyDamage = "body damage"
    case safety = "safety"
    case other = "other"
}

enum DriverReportSeverity: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case critical = "critical"
}

enum DriverReportStatus: String, Codable, CaseIterable {
    case reported = "reported"
    case acknowledged = "acknowledged"
    case convertedToWorkOrder = "converted_to_work_order"
    case resolved = "resolved"
}

struct DriverReport: Identifiable, Codable {
    let id: UUID
    var driverId: UUID?
    var vehicleId: UUID?
    var tripId: UUID?
    var category: DriverReportCategory
    var severity: DriverReportSeverity
    var description: String
    var status: DriverReportStatus
    let createdAt: Date?
    
    // Joined data
    var vehicle: WorkOrderVehicle?

    enum CodingKeys: String, CodingKey {
        case id
        case driverId = "driver_id"
        case vehicleId = "vehicle_id"
        case tripId = "trip_id"
        case category
        case severity
        case description
        case status
        case createdAt = "created_at"
        case vehicle = "vehicles"
    }
}
