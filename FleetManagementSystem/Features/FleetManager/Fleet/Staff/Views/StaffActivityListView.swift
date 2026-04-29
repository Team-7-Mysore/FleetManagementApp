//
//  StaffActivityListView.swift
//  FleetManagementSystem
//

import SwiftUI
internal import PostgREST
import Supabase

struct StaffActivityListView: View {
    let staff: StaffUser
    @Environment(\.dismiss) private var dismiss
    
    @State private var activities: [ActivityItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    struct ActivityItem: Identifiable {
        let id: String
        let title: String
        let status: String
        let timestamp: String
        let detail1: String? // distance for trips, priority for work orders
        let detail2: String? // route for trips, vehicle for work orders
    }
    
    private var accentColor: Color {
        switch staff.role {
        case .driver:      return Color(red: 59/255,  green: 13/255,  blue: 17/255)
        case .maintenance: return Color(red: 30/255,  green: 80/255,  blue: 160/255)
        case .manager:     return Color(red: 40/255,  green: 120/255, blue: 70/255)
        }
    }
    
    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading activities...")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else if activities.isEmpty {
                Text("No activities found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(activities) { activity in
                    activityRow(activity)
                }
            }
        }
        .navigationTitle("All Activities")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchAllActivities()
        }
    }
    
    @ViewBuilder
    private func activityRow(_ activity: ActivityItem) -> some View {
        HStack(spacing: 16) {
            let statusRaw = activity.status.lowercased()
            
            ZStack {
                Circle()
                    .fill(statusColor(statusRaw).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: statusIcon(statusRaw))
                    .font(.title3)
                    .foregroundColor(statusColor(statusRaw))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(activity.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    if let d1 = activity.detail1 {
                        Text(d1)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                if let d2 = activity.detail2 {
                    Text(d2)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(activity.timestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    statusBadge(statusRaw)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        let label = status.capitalized
        let color = statusColor(status)
        
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .textCase(.uppercase)
    }
    
    private func statusColor(_ raw: String) -> Color {
        if staff.role == .driver {
            switch raw {
            case "completed": return .green
            case "ongoing", "in_transit", "in_progress": return .blue
            case "assigned", "scheduled": return .orange
            case "cancelled", "canceled": return .red
            default: return .gray
            }
        } else {
            switch raw {
            case "completed": return .green
            case "in progress": return .blue
            case "pending": return .orange
            case "cancelled": return .red
            default: return .gray
            }
        }
    }
    
    private func statusIcon(_ raw: String) -> String {
        if staff.role == .driver {
            switch raw {
            case "completed": return "checkmark.circle.fill"
            case "ongoing", "in_transit", "in_progress": return "location.circle.fill"
            case "assigned", "scheduled": return "clock.fill"
            case "cancelled", "canceled": return "xmark.circle.fill"
            default: return "questionmark.circle.fill"
            }
        } else {
            switch raw {
            case "completed": return "checkmark.circle.fill"
            case "in progress": return "hammer.fill"
            case "pending": return "clock.fill"
            case "cancelled": return "xmark.circle.fill"
            default: return "questionmark.circle.fill"
            }
        }
    }
    
    private func fetchAllActivities() async {
        if staff.role == .driver {
            await fetchAllTrips()
        } else if staff.role == .maintenance {
            await fetchAllWorkOrders()
        }
    }
    
    private func fetchAllTrips() async {
        do {
            // Fetch driver_id first
            let drivers: [DriverRecord] = try await SupabaseManager.shared.client
                .from("drivers")
                .select("driver_id")
                .eq("user_id", value: staff.user_id)
                .limit(1)
                .execute()
                .value
            
            guard let driverId = drivers.first?.driver_id else {
                await MainActor.run { isLoading = false }
                return
            }
            
            let rows: [DriverTripRow] = try await SupabaseManager.shared.client
                .from("trips")
                .select("trip_id, trip_name, origin, destination, distance_travelled, start_time, end_time, status")
                .eq("driver_id", value: driverId)
                .eq("status", value: "completed")
                .order("end_time", ascending: false)
                .execute()
                .value
            
            let items = rows.map { row in
                ActivityItem(
                    id: row.trip_id,
                    title: row.trip_name ?? "Unnamed Trip",
                    status: row.status ?? "unknown",
                    timestamp: formatTimestamp(row.end_time ?? row.start_time ?? ""),
                    detail1: row.distance_travelled.map { formatDistance($0) },
                    detail2: formatRoute(origin: row.origin, destination: row.destination)
                )
            }
            
            await MainActor.run {
                self.activities = items
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func fetchAllWorkOrders() async {
        do {
            let rows: [WorkOrderRow] = try await SupabaseManager.shared.client
                .from("work_orders")
                .select("work_order_id, issue_title, priority, status, created_at, updated_at")
                .eq("maintenance_personnel_id", value: staff.user_id)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            let items = rows.map { row in
                ActivityItem(
                    id: row.work_order_id,
                    title: row.issue_title,
                    status: row.status ?? "unknown",
                    timestamp: formatTimestamp(row.created_at ?? ""),
                    detail1: row.priority?.uppercased(),
                    detail2: nil
                )
            }
            
            await MainActor.run {
                self.activities = items
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helpers (copied/adapted from StaffProfileView)
    
    private func formatTimestamp(_ raw: String) -> String {
        guard let d = parseTimestamp(raw) else { return raw }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: d)
    }
    
    private func parseTimestamp(_ raw: String) -> Date? {
        let formats = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm:ss.SSSSSS"]
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        for f in formats {
            fmt.dateFormat = f
            if let d = fmt.date(from: raw) { return d }
        }
        return nil
    }
    
    private func formatDistance(_ km: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return "\(formatter.string(from: NSNumber(value: km)) ?? "0") km"
    }
    
    private func formatRoute(origin: String?, destination: String?) -> String? {
        guard let o = origin, let d = destination else { return nil }
        let sO = o.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? o
        let sD = d.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? d
        return "\(sO) → \(sD)"
    }
    
    // Local models to match fetching
    private struct DriverRecord: Decodable {
        let driver_id: String
    }
    private struct DriverTripRow: Decodable {
        let trip_id: String
        let trip_name: String?
        let origin: String?
        let destination: String?
        let distance_travelled: Double?
        let start_time: String?
        let end_time: String?
        let status: String?
    }
    private struct WorkOrderRow: Decodable {
        let work_order_id: String
        let issue_title: String
        let priority: String?
        let status: String?
        let created_at: String?
        let updated_at: String?
    }
}
