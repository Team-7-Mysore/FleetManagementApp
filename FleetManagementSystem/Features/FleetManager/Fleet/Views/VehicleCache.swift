//
//  VehicleCache.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 22/04/26.
//


import Foundation

actor VehicleCache {
    // Shared singleton instance
    static let shared = VehicleCache()
    
    private var cache: [UUID: Vehicle] = [:]
    
    // Retrieve a vehicle from the cache
    func getVehicle(id: UUID) -> Vehicle? {
        return cache[id]
    }
    
    // Save or update a vehicle in the cache
    func saveVehicle(_ vehicle: Vehicle, id: UUID) {
        cache[id] = vehicle
    }
    
    // Optional: Clear the cache completely (useful for logouts)
    func clearCache() {
        cache.removeAll()
    }
}