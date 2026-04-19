
//
//  StaffListViewModel.swift
//  FleetManagementSystem
//
//  Fetches staff (driver + maintenance) from public.users,
//  exposes search, status filter, and role filter.
//

import Foundation
import Combine
internal import PostgREST
import Supabase

@MainActor
final class StaffListViewModel: ObservableObject {

    @Published var allStaff:      [StaffUser] = []
    @Published var isLoading:     Bool        = false
    @Published var errorMessage:  String?     = nil

    // Filters
    @Published var searchText:    String         = ""
    @Published var selectedStatus: AccountStatus? = nil
    @Published var selectedRole:   UserRole?      = nil

    // ——— Derived filtered list ———
    var filteredStaff: [StaffUser] {
        allStaff.filter { user in
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
                guard let status = selectedStatus else { return true }
                return user.status == status
            }()

            // Role filter
            let matchesRole: Bool = {
                guard let role = selectedRole else { return true }
                return user.role == role
            }()

            return matchesSearch && matchesStatus && matchesRole
        }
    }

    var activeFilterCount: Int {
        (selectedStatus != nil ? 1 : 0) + (selectedRole != nil ? 1 : 0)
    }

    // ——— Fetch from Supabase ———
    func fetchStaff() {
        isLoading    = true
        errorMessage = nil

        Task {
            do {
                let staff: [StaffUser] = try await SupabaseManager.shared.client
                    .from("users")
                    .select()
                    .in("role", values: ["driver", "maintenance"])
                    .order("name")
                    .execute()
                    .value

                self.allStaff  = staff
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading    = false
            }
        }
    }

    func clearFilters() {
        selectedStatus = nil
        selectedRole   = nil
        searchText     = ""
    }
}
