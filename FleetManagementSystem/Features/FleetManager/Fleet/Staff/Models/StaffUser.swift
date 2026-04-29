
//
//  StaffUser.swift
//  FleetManagementSystem
//
//  Decodable representation of a row in public.users
//

import Foundation

// Maps to the user_role enum in Supabase
enum UserRole: String, Codable, CaseIterable {
    case driver      = "driver"
    case maintenance = "maintenance"
    case manager     = "manager"

    var displayName: String {
        switch self {
        case .driver:      return "Driver"
        case .maintenance: return "Maintenance Staff"
        case .manager:     return "Manager"
        }
    }

    var icon: String {
        switch self {
        case .driver:      return "car.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .manager:     return "person.badge.key.fill"
        }
    }
}

// Maps to an account_status enum — extend DB if needed
enum AccountStatus: String, Codable, CaseIterable {
    case active   = "active"
    case pending  = "pending"
    case inactive = "inactive"

    var displayName: String { rawValue.capitalized }

    var color: String {          // used via Color(hex:) or named
        switch self {
        case .active:   return "active"
        case .pending:  return "pending"
        case .inactive: return "inactive"
        }
    }
}

struct StaffUser: Identifiable, Decodable {
    let user_id:    String
    var name:       String
    let email:      String
    let role:       UserRole
    var phone_no:   String?
    let username:   String?
    let status:     AccountStatus?
    let created_by: String?

    var id: String { user_id }

    var initials: String {
        let parts = name.split(separator: " ")
        let f = parts.first?.first.map(String.init) ?? ""
        let l = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}
