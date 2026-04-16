//
//  ModelFile.swift
//  FleetManagementSystem
//
//  Created by Dhaani on 16/04/26.
//

import Foundation

// MARK: - Enums
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

// MARK: - Inventory Model
struct InventoryItem: Identifiable, Codable {
    let id: UUID
    var partName: String
    var category: String?
    var categoryDescription: String?
    var supplier: String?
    var quantity: Int
    var costPerUnit: Double?
    var sku: String?
    var location: String?
    var imageUrl: String? // Supabase Storage URL
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case partName = "part_name"
        case category
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

// MARK: - Main Work Order Model
struct WorkOrder: Identifiable, Codable {
    let id: UUID
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
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Work Order Task (Checklist)
struct WorkOrderTask: Identifiable, Codable {
    let id: UUID
    var workOrderId: UUID
    var description: String
    var isCompleted: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case workOrderId = "work_order_id"
        case description
        case isCompleted = "is_completed"
        case createdAt = "created_at"
    }
}

// MARK: - Work Order Part (Linked Inventory)
struct WorkOrderPart: Codable {
    // Note: No 'id' here since the Primary Key is the combination of these two IDs
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

// MARK: - Work Order Image (Documentation)
struct WorkOrderImage: Identifiable, Codable {
    let id: UUID
    var workOrderId: UUID
    var imageUrl: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case workOrderId = "work_order_id"
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }
}
