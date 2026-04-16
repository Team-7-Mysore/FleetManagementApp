//
//  SupabaseManager.swift
//  FleetManagementSystem
//
//  Created by Apple on 16/04/26.
//


import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
}