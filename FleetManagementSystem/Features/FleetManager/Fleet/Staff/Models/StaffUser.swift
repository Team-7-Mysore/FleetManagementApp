
//
//  StaffUser.swift
//  FleetManagementSystem
//
//  Decodable representation of a row in public.users
//

import Foundation

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
    let name:       String
    let email:      String
    let role:       AppUserRole
    let phone_no:   String?
    let username:   String?
    let status:     AccountStatus?

    var id: String { user_id }

    var initials: String {
        let parts = name.split(separator: " ")
        let f = parts.first?.first.map(String.init) ?? ""
        let l = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }
}
