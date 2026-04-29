//
//  Driver.swift
//  FleetManagementSystem
//
//  Created by Kiro AI
//

import Foundation

struct Driver: Identifiable, Codable {
    let driverId: UUID
    let userId: UUID?
    let licenseNo: String
    let licenseExpiry: String
    let licenseImageURL: String?
    
    var id: UUID { driverId }
    
    enum CodingKeys: String, CodingKey {
        case driverId = "driver_id"
        case userId = "user_id"
        case licenseNo = "license_no"
        case licenseExpiry = "license_expiry"
        case licenseImageURL = "license_image_url"
    }
}
