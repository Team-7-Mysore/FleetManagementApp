//
//  StaffListViewModel.swift
//  FleetManagementSystem
//
//  Fetches staff (driver + maintenance) from public.users,
//  exposes search, status filter, role filter, and sort order.
//

import Foundation
import Combine
internal import PostgREST
import Supabase

// MARK: - Sort Order

enum StaffSortOrder: String, CaseIterable, Identifiable {
    case newest      = "Newest First"
    case nameAsc     = "A → Z"
    case nameDesc    = "Z → A"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .newest:   return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .nameAsc:  return "arrow.up.circle"
        case .nameDesc: return "arrow.down.circle"
        }
    }
}

@MainActor
final class StaffListViewModel: ObservableObject {

    @Published var allStaff:      [StaffUser] = []
    @Published var isLoading:     Bool        = false
    @Published var errorMessage:  String?     = nil
    @Published var hasLoadedData: Bool        = false

    // Filters
    @Published var searchText:     String           = ""
    @Published var selectedStatus: AccountStatus?   = nil
    @Published var selectedRole:   UserRole?        = nil
    @Published var selectedSort:   StaffSortOrder   = .newest

    // ——— Derived filtered + sorted list ———
    var filteredStaff: [StaffUser] {
        let filtered = allStaff.filter { user in
            // Search
            let matchesSearch: Bool = {
                guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
                let q = searchText.lowercased()
                return user.name.lowercased().contains(q)
                    || user.email.lowercased().contains(q)
                    || (user.phone_no?.lowercased().contains(q) ?? false)
                    || (user.username?.lowercased().contains(q) ?? false)
            }()

            // Status filter
            let matchesStatus: Bool = {
                if let status = selectedStatus {
                    return user.status == status
                } else {
                    // Default: only show active/pending staff (exclude inactive)
                    return user.status != .inactive
                }
            }()

            // Role filter
            let matchesRole: Bool = {
                guard let role = selectedRole else { return true }
                return user.role == role
            }()

            return matchesSearch && matchesStatus && matchesRole
        }

        // Sort
        switch selectedSort {
        case .newest:   return filtered  // already ordered by created_at desc from Supabase
        case .nameAsc:  return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc: return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
    }

    var activeFilterCount: Int {
        (selectedStatus != nil ? 1 : 0)
        + (selectedRole != nil ? 1 : 0)
        + (selectedSort != .newest ? 1 : 0)
    }

    // ——— Fetch from Supabase ———
    func fetchStaff(forceRefresh: Bool = false) {
        if !forceRefresh && hasLoadedData { return }
        isLoading    = true
        errorMessage = nil

        Task {
            do {
                let staff: [StaffUser] = try await SupabaseManager.shared.client
                    .from("users")
                    .select()
                    .in("role", values: ["driver", "maintenance"])
                    .in("status", values: ["active", "pending", "inactive"])
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                self.allStaff  = staff
                self.hasLoadedData = true
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading    = false
            }
        }
    }

    func deactivateStaff(_ userId: String) {
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("users")
                    .update(["status": "inactive"])
                    .eq("user_id", value: userId)
                    .execute()
                
                fetchStaff(forceRefresh: true)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func deleteStaff(_ userId: String) {
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("users")
                    .delete()
                    .eq("user_id", value: userId)
                    .execute()
                
                fetchStaff(forceRefresh: true)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func clearFilters() {
        selectedStatus = nil
        selectedRole   = nil
        selectedSort   = .newest
        searchText     = ""
    }
}
