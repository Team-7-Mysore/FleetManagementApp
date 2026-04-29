//
//  SupabaseManager.swift
//  FleetManagementSystem
//
//  Created by Apple on 16/04/26.
//


import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        let memoryCapacity = 50 * 1024 * 1024 // 50 MB
        let diskCapacity = 100 * 1024 * 1024 // 100 MB
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "supabase_cache")
        URLCache.shared = cache
        
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .useProtocolCachePolicy
        
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                ),
                global: .init(session: URLSession(configuration: config))
            )
        )
    }

    func isSessionValid() async -> Bool {
        do {
            let session = try await client.auth.session
            return !session.isExpired
        } catch {
            return false
        }
    }
}
