//
//  StaffListView.swift
//  FleetManagementSystem
//
//  Staff list — matches TripsListView layout: insetGrouped List, overview card, cards as rows, FAB
//

import SwiftUI

struct StaffListView: View {

    @StateObject private var vm = StaffListViewModel()
    @State private var navigateToAddPerson = false
    @State private var showFilter          = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {

                List {
                    // ——— Active filter chips ———
                    if vm.activeFilterCount > 0 {
                        Section {
                            ActiveFilterChipsRow(vm: vm)
                                .listRowInsets(EdgeInsets())
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    // ——— Staff cards section ———
                    Section {
                        if vm.isLoading {
                            staffLoadingState
                        } else if vm.filteredStaff.isEmpty {
                            EmptyStaffView(
                                hasFilters: vm.activeFilterCount > 0 || !vm.searchText.isEmpty,
                                onClear: { vm.clearFilters() }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(vm.filteredStaff) { staff in
                                ZStack {
                                    NavigationLink(destination: StaffProfileView(staff: staff)) {
                                        EmptyView()
                                    }
                                    .opacity(0)

                                    StaffCard(staff: staff)
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    } header: {
                        staffSectionHeader
                    } footer: {
                        if !vm.isLoading && !vm.filteredStaff.isEmpty {
                            Text("Pull down to refresh the latest staff status.")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .searchable(text: $vm.searchText, prompt: "Search staff…")
                .navigationTitle("Staff")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        toolbarIconButton(systemName: "slider.horizontal.3") { showFilter = true }
                        toolbarIconButton(systemName: "bell") {}
                    }
                }
                .task { vm.fetchStaff() }
                .refreshable { vm.fetchStaff() }
                .sheet(isPresented: $showFilter) {
                    StaffFilterSheet(vm: vm)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
                .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                    Button("Retry") { vm.fetchStaff() }
                    Button("Dismiss", role: .cancel) { vm.errorMessage = nil }
                } message: {
                    Text(vm.errorMessage ?? "")
                }
                .navigationDestination(isPresented: $navigateToAddPerson) {
                    AddPersonFlowView()
                }

                // ——— FAB ———
                Button { navigateToAddPerson = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.TechBlue)
                        .clipShape(Circle())
                        .shadow(radius: 6)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
    }


    private var staffSectionHeader: some View {
        HStack {
            Text("All Staff")
            Spacer()
            if vm.activeFilterCount > 0 {
                Button("Clear Filters") { vm.clearFilters() }
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
            }
        }
    }

    // MARK: - Loading State

    private var staffLoadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Loading staff…")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Toolbar Button

    private func toolbarIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
        }
    }
}



// MARK: - Active Filter Chips Row

private struct ActiveFilterChipsRow: View {
    @ObservedObject var vm: StaffListViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let status = vm.selectedStatus {
                    FilterChip(
                        icon: statusIcon(status),
                        label: status.displayName,
                        color: statusColor(status)
                    ) {
                        withAnimation(.spring(response: 0.3)) { vm.selectedStatus = nil }
                    }
                }
                if let role = vm.selectedRole {
                    FilterChip(
                        icon: role.icon,
                        label: role.displayName,
                        color: Color.TechBlue
                    ) {
                        withAnimation(.spring(response: 0.3)) { vm.selectedRole = nil }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func statusIcon(_ status: AccountStatus) -> String {
        switch status {
        case .active:   return "checkmark.circle.fill"
        case .pending:  return "clock.fill"
        case .inactive: return "minus.circle.fill"
        }
    }

    private func statusColor(_ status: AccountStatus) -> Color {
        switch status {
        case .active:   return Color(red: 0.1, green: 0.72, blue: 0.35)
        case .pending:  return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .inactive: return Color.gray
        }
    }
}


// MARK: - Staff Card

private struct StaffCard: View {
    let staff: StaffUser

    private var accentColor: Color {
        switch staff.role {
        case .driver:      return Color(red: 59/255,  green: 13/255,  blue: 17/255)
        case .maintenance: return Color(red: 30/255,  green: 80/255,  blue: 160/255)
        case .manager:     return Color(red: 40/255,  green: 120/255, blue: 70/255)
        }
    }

    var body: some View {
        HStack(spacing: 14) {

            // —— Role icon circle (mirrors TripCardView's icon circle) ——
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: staff.role.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 8) {

                // Top row: name + status badge
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(staff.name)
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                        Text(staff.role.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    if let status = staff.status {
                        Text(status.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(statusColor(status))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(statusColor(status).opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.gray.opacity(0.4))
                }

                // Email row
                HStack(spacing: 6) {
                    Image(systemName: "envelope")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text(staff.email)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                // Phone row
                if let phone = staff.phone_no, !phone.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "phone")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Text(phone)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func statusColor(_ status: AccountStatus) -> Color {
        switch status {
        case .active:   return Color(red: 0.1, green: 0.72, blue: 0.35)
        case .pending:  return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .inactive: return .gray
        }
    }
}




// MARK: - Status Badge

private struct StatusBadge1: View {
    let status: AccountStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(status.displayName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(dotColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(dotColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private var dotColor: Color {
        switch status {
        case .active:   return Color(red: 0.1, green: 0.72, blue: 0.35)
        case .pending:  return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .inactive: return Color.gray
        }
    }
}

// MARK: - Filter Chip (active filters shown below search bar)

private struct FilterChip: View {
    let icon:     String
    let label:    String
    let color:    Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(color)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color.opacity(0.7))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(color.opacity(0.1))
        .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
        .clipShape(Capsule())
        .shadow(color: color.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Filter Sheet

struct StaffFilterSheet: View {
    @ObservedObject var vm: StaffListViewModel
    @Environment(\.dismiss) private var dismiss

    private func statusRow(_ status: AccountStatus) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 9, height: 9)
            Text(status.displayName)
                .font(.system(size: 15, design: .rounded))
            Spacer()
            if vm.selectedStatus == status {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.brown)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            vm.selectedStatus = (vm.selectedStatus == status) ? nil : status
        }
    }

    private func roleRow(_ role: UserRole) -> some View {
        HStack(spacing: 10) {
            Image(systemName: role.icon)
                .font(.system(size: 14))
                .foregroundColor(.brown)
                .frame(width: 20)
            Text(role.displayName)
                .font(.system(size: 15, design: .rounded))
            Spacer()
            if vm.selectedRole == role {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.brown)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            vm.selectedRole = (vm.selectedRole == role) ? nil : role
        }
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Status ──
                Section("Status") {
                    ForEach(Array(AccountStatus.allCases), id: \.self) { status in
                        statusRow(status)
                    }
                }

                // ── Role ──
                Section("Role") {
                    ForEach([UserRole.driver, UserRole.maintenance], id: \.self) { role in
                        roleRow(role)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") { vm.clearFilters() }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(vm.activeFilterCount > 0 ? .brown : .gray)
                        .disabled(vm.activeFilterCount == 0)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.brown)
                }
            }
        }
    }

    private func statusColor(_ status: AccountStatus) -> Color {
        switch status {
        case .active:   return Color(red: 0.1, green: 0.72, blue: 0.35)
        case .pending:  return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .inactive: return Color.gray
        }
    }
}

// MARK: - Empty State

private struct EmptyStaffView: View {
    let hasFilters: Bool
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: hasFilters ? "line.3.horizontal.decrease.circle" : "person.3")
                .font(.system(size: 48))
                .foregroundColor(Color.gray.opacity(0.35))

            Text(hasFilters ? "No matching staff" : "No staff yet")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text(hasFilters ? "Try adjusting your search or filters." : "Tap + to add your first staff member.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if hasFilters {
                Button("Clear Filters", action: onClear)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.TechBlue)
                    .cornerRadius(10)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}

#Preview {
    StaffListView()
}
