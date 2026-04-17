
//
//  StaffListView.swift
//  FleetManagementSystem
//
//  Staff list — search bar, filter (status + role), card list, FAB
//

import SwiftUI

struct StaffListView: View {

    @StateObject private var vm = StaffListViewModel()
    @State private var navigateToAddPerson = false
    @State private var showFilter          = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {

                VStack(spacing: 0) {

                    // ——— Search + Filter Bar ———
                    SearchFilterBar(
                        searchText: $vm.searchText,
                        isSearchFocused: $isSearchFocused,
                        activeFilterCount: vm.activeFilterCount,
                        onFilterTap: { showFilter = true }
                    )

                    // ——— Active filter chips ———
                    if vm.activeFilterCount > 0 {
                        ActiveFilterChipsRow(vm: vm)
                    }

                    // ——— List ———
                    if vm.isLoading {
                        Spacer()
                        ProgressView("Loading staff…")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()

                    } else if vm.filteredStaff.isEmpty {
                        EmptyStaffView(hasFilters: vm.activeFilterCount > 0 || !vm.searchText.isEmpty) {
                            vm.clearFilters()
                        }

                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(vm.filteredStaff) { staff in
                                    NavigationLink(destination: StaffProfileView(staff: staff)) {
                                        StaffCard(staff: staff)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 100)
                        }
                        .background(Color(.systemGray6))
                        .refreshable { vm.fetchStaff() }
                    }
                }

                // ——— FAB ———
                Button { navigateToAddPerson = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 58)
                        .background(Color.primaryBrown)
                        .clipShape(Circle())
                        .shadow(color: Color.primaryBrown.opacity(0.45), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 28)
            }
            .navigationTitle("Staff")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGray6))
            .navigationDestination(isPresented: $navigateToAddPerson) {
                AddPersonFlowView()
            }
            .task { vm.fetchStaff() }
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
            .onTapGesture { isSearchFocused = false }
        }
    }
}

// MARK: - Search + Filter Bar

private struct SearchFilterBar: View {
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    let activeFilterCount: Int
    let onFilterTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {

            // ── Search pill ──
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSearchFocused.wrappedValue ? Color.primaryBrown : Color.gray)
                    .animation(.easeInOut(duration: 0.2), value: isSearchFocused.wrappedValue)

                TextField("Search staff…", text: $searchText)
                    .font(.system(size: 15, design: .rounded))
                    .autocorrectionDisabled()
                    .focused(isSearchFocused)

                if !searchText.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3)) { searchText = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.gray.opacity(0.6))
                            .font(.system(size: 15))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: isSearchFocused.wrappedValue
                            ? Color.primaryBrown.opacity(0.18)
                            : Color.black.opacity(0.06),
                           radius: isSearchFocused.wrappedValue ? 8 : 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSearchFocused.wrappedValue
                            ? Color.primaryBrown.opacity(0.5)
                            : Color.clear,
                        lineWidth: 1.5
                    )
                    .animation(.easeInOut(duration: 0.2), value: isSearchFocused.wrappedValue)
            )

            // ── Filter button ──
            Button(action: onFilterTap) {
                ZStack(alignment: .topTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                        if activeFilterCount == 0 {
                            Text("Filter")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundColor(activeFilterCount > 0 ? .white : Color.primaryBrown)
                    .padding(.horizontal, activeFilterCount > 0 ? 14 : 16)
                    .padding(.vertical, 11)
                    .background(
                        Group {
                            if activeFilterCount > 0 {
                                LinearGradient(
                                    colors: [Color.primaryBrown, Color.primaryBrown.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                LinearGradient(
                                    colors: [Color.primaryBrown.opacity(0.1), Color.primaryBrown.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                activeFilterCount > 0 ? Color.clear : Color.primaryBrown.opacity(0.25),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: activeFilterCount > 0 ? Color.primaryBrown.opacity(0.30) : .clear,
                        radius: 6, x: 0, y: 3
                    )

                    // Badge
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.primaryBrown)
                            .frame(width: 16, height: 16)
                            .background(Color.white)
                            .clipShape(Circle())
                            .offset(x: 5, y: -5)
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: activeFilterCount)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(.systemGray6)
                .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
        )
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
                        color: Color.primaryBrown
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

    private func roleGradient(_ role: UserRole) -> LinearGradient {
        switch role {
        case .driver:
            return LinearGradient(
                colors: [Color(red: 59/255, green: 13/255, blue: 17/255),
                         Color(red: 110/255, green: 40/255, blue: 48/255)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .maintenance:
            return LinearGradient(
                colors: [Color(red: 25/255, green: 70/255, blue: 150/255),
                         Color(red: 60/255, green: 120/255, blue: 195/255)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .manager:
            return LinearGradient(
                colors: [Color(red: 40/255, green: 120/255, blue: 70/255),
                         Color(red: 80/255, green: 160/255, blue: 110/255)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Top row: avatar + name/status + chevron ──
            HStack(spacing: 12) {

                // Avatar with ring
                ZStack {
                    Circle()
                        .fill(roleGradient(staff.role))
                        .frame(width: 50, height: 50)
                    Text(staff.initials)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .overlay(
                    Circle()
                        .strokeBorder(accentColor.opacity(0.25), lineWidth: 2.5)
                )

                // Details: Name line + Role line
                VStack(alignment: .leading, spacing: 4) {
                    
                    // Name + Status + Chevron
                    HStack(spacing: 8) {
                        Text(staff.name)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            
                        Spacer()
                        
                        // Status badge
                        if let status = staff.status {
                            StatusBadge(status: status)
                        }
                        // Chevron
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.gray.opacity(0.35))
                    }

                    // Role capsule
                    HStack(spacing: 5) {
                        Image(systemName: staff.role.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(staff.role.displayName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // ── Divider ──
            Divider()
                .padding(.horizontal, 14)

            // ── Bottom info row: email + phone badges ──
            HStack(spacing: 8) {
                InfoBadge(icon: "envelope.fill",
                          text: staff.email,
                          iconColor: accentColor)

                if let phone = staff.phone_no, !phone.isEmpty {
                    InfoBadge(icon: "phone.fill",
                              text: phone,
                              iconColor: accentColor)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: accentColor.opacity(0.10), radius: 8, x: 0, y: 3)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Info Badge (email / phone in bottom strip)

private struct InfoBadge: View {
    let icon:      String
    let text:      String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(iconColor)
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.75))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(iconColor.opacity(0.07))
        .overlay(
            Capsule()
                .strokeBorder(iconColor.opacity(0.15), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
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

    var body: some View {
        NavigationStack {
            List {

                // ── Status ──
                Section("Status") {
                    ForEach(AccountStatus.allCases, id: \.self) { status in
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
                                    .foregroundColor(Color.primaryBrown)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.selectedStatus = (vm.selectedStatus == status) ? nil : status
                        }
                    }
                }

                // ── Role ──
                Section("Role") {
                    ForEach([UserRole.driver, UserRole.maintenance], id: \.self) { role in
                        HStack(spacing: 10) {
                            Image(systemName: role.icon)
                                .font(.system(size: 14))
                                .foregroundColor(Color.primaryBrown)
                                .frame(width: 20)
                            Text(role.displayName)
                                .font(.system(size: 15, design: .rounded))
                            Spacer()
                            if vm.selectedRole == role {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.primaryBrown)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            vm.selectedRole = (vm.selectedRole == role) ? nil : role
                        }
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
                        .foregroundColor(vm.activeFilterCount > 0 ? Color.primaryBrown : .gray)
                        .disabled(vm.activeFilterCount == 0)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.primaryBrown)
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
                    .background(Color.primaryBrown)
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
