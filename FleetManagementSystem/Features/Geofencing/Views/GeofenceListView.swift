//
//  GeofenceListView.swift
//  FleetManagementSystem
//
//  Created by Kiro on 2025
//

import SwiftUI

struct GeofenceListView: View {
    @StateObject private var viewModel = GeofenceViewModel()
    var profile: UserProfile?
    
    @State private var searchText: String = ""
    @State private var selectedType: GeofenceType? = nil
    @State private var showingCreateSheet: Bool = false
    
    // Computed property for filtered geofences
    private var filteredGeofences: [Geofence] {
        var result = viewModel.geofences
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { geofence in
                geofence.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by type
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let errorMessage = viewModel.errorMessage {
                    errorStateView(message: errorMessage)
                } else if viewModel.geofences.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Geofences")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search geofences")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isFleetManager {
                        Button {
                            showingCreateSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                GeofenceCreateEditView(profile: profile, viewModel: viewModel, mode: .create, existingGeofence: nil)
            }
            .task {
                if viewModel.geofences.isEmpty {
                    await viewModel.loadGeofences()
                }
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        VStack(spacing: 0) {
            // Type filter picker
            typePicker
            
            // Geofence list
            if filteredGeofences.isEmpty {
                noResultsView
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(filteredGeofences) { geofence in
                            NavigationLink {
                                GeofenceDetailView(geofence: geofence, profile: profile)
                            } label: {
                                GeofenceRowView(geofence: geofence)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - Type Picker
    
    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All types option
                GeofenceFilterChip(
                    title: "All",
                    isSelected: selectedType == nil,
                    action: { selectedType = nil }
                )
                
                // Individual type filters
                ForEach(GeofenceType.allCases, id: \.self) { type in
                    GeofenceFilterChip(
                        title: type.displayName,
                        icon: type.icon,
                        color: type.color,
                        isSelected: selectedType == type,
                        action: { selectedType = type }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Geofences")
                .font(.title2.weight(.semibold))
            
            if isFleetManager {
                Text("Create your first geofence to start monitoring vehicle locations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button {
                    showingCreateSheet = true
                } label: {
                    Label("Create Geofence", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.top, 8)
            } else {
                Text("No geofences have been created yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    // MARK: - No Results View
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.headline)
            
            Text("Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }
    
    // MARK: - Error State
    
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Could Not Load Geofences")
                .font(.title2.weight(.semibold))
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await viewModel.loadGeofences()
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Helpers
    
    private var isFleetManager: Bool {
        profile?.role == .fleetManager
    }
}

// MARK: - Geofence Row View

struct GeofenceRowView: View {
    let geofence: Geofence
    
    var body: some View {
        HStack(spacing: 16) {
            // Type icon
            Image(systemName: geofence.type.icon)
                .font(.title2)
                .foregroundColor(geofence.type.color)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(geofence.type.color.opacity(0.15))
                )
            
            // Geofence info
            VStack(alignment: .leading, spacing: 4) {
                Text(geofence.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(geofence.type.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(formattedDate(geofence.created_at))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.cardShadowRadius, x: 0, y: AppTheme.cardShadowY)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Geofence Filter Chip

struct GeofenceFilterChip: View {
    let title: String
    var icon: String? = nil
    var color: Color? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                }
                
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? (color ?? AppTheme.primaryGreen) : Color(.tertiarySystemGroupedBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GeofenceListView()
    }
}
