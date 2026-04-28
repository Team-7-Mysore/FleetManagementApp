//
//  StaffProfileView.swift
//  FleetManagementSystem
//
//  Profile detail screen for staff members (Simplified Form Style)
//  Extended with live Supabase data: drivers, trips, vehicles
//

import SwiftUI
import Charts
import Supabase

// MARK: - Local Models (private to this file)

private struct DriverRecord: Decodable {
    let driver_id: String
    let license_no: String
    let license_expiry: String
}

private struct DriverTripRow: Decodable {
    let trip_id:            String
    let trip_name:          String?
    let origin:             String?
    let destination:        String?
    let distance_travelled: Double?
    let start_time:         String?
    let end_time:           String?
    let status:             String?
    let vehicle_id:         String?
}

private struct VehicleRow: Decodable {
    let vehicle_id:   String
    let number_plate: String
    let vehicle_type: String?
    let vehicle_name: String?
}

private struct TripStats {
    var totalTrips:    Int    = 0
    var totalDistance: Double = 0
    var lastTripDate:  Date?  = nil
}

private struct CreatorRecord: Decodable {
    let name: String
}

// MARK: - Maintenance Models
private struct WorkOrderRow: Decodable {
    let work_order_id: String
    let issue_title: String
    let priority: String?
    let status: String?
    let vehicle_id: String?
    let created_at: String?
    let updated_at: String?
    let hours_worked: Double?
    let est_cost: Double?
}

private struct TaskRow: Decodable {
    let task_id: String
    let description: String?
    let is_completed: Bool?
}

private struct StaffPartRow: Decodable {
    let work_order_id: String
    let quantity_required: Int?
    let cost_at_time: Double?
    let inventory_id: String?
}

private struct InventoryRow: Decodable {
    let part_name: String
}

private struct IssueRow: Decodable {
    let issue_id: String
    let status: String?
    let issue_summary: String?
}

private struct ReportRow: Decodable {
    let report_name: String
    let report_url: String?
}

private struct WorkStats {
    var completedOrders: Int = 0
    var totalHours: Double = 0
    var totalCost: Double = 0
}

private struct TaskSummary {
    var total: Int = 0
    var completed: Int = 0
}

private struct IssueSummary {
    var pending: Int = 0
    var inProgress: Int = 0
    var completed: Int = 0
}

// MARK: - StaffProfileView

struct StaffProfileView: View {
    let staff: StaffUser

    @Environment(\.dismiss) private var dismiss

    // Existing state
    @State private var creatorName:              String?      = nil
    @State private var isDeactivating:           Bool         = false
    @State private var errorMessage:             String?      = nil
    @State private var showAlert:                Bool         = false
    @State private var showDeactivateConfirmation: Bool       = false

    // New state – driver data
    @State private var driverDetails:  DriverRecord?   = nil
    @State private var tripStats:      TripStats       = TripStats()
    @State private var activeTrip:     DriverTripRow?  = nil
    @State private var recentTrips:    [DriverTripRow] = []
    @State private var vehicleInfo:    VehicleRow?     = nil

    // Loading / error flags for new data
    @State private var isLoadingDriver: Bool   = false
    @State private var driverError:     String? = nil

    // New state - maintenance data
    @State private var activeWorkOrder: WorkOrderRow? = nil
    @State private var activeWorkOrderVehicle: VehicleRow? = nil
    @State private var workStats = WorkStats()
    @State private var recentWorkOrders: [WorkOrderRow] = []
    @State private var taskSummary = TaskSummary()
    @State private var partsCost: Double = 0
    @State private var issueSummary = IssueSummary()
    @State private var lastActivityDate: Date? = nil

    @State private var isLoadingMaintenance: Bool = false
    @State private var maintenanceError: String? = nil

    // MARK: Accent colour (unchanged)
    private var accentColor: Color {
        switch staff.role {
        case .driver:      return Color(red: 59/255,  green: 13/255,  blue: 17/255)
        case .maintenance: return Color(red: 30/255,  green: 80/255,  blue: 160/255)
        case .manager:     return Color(red: 40/255,  green: 120/255, blue: 70/255)
        }
    }

    // MARK: Body
    var body: some View {
        Form {

            // ── 1. HEADER ──────────────────────────────────
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.12))
                            .frame(width: 90, height: 90)
                        Text(staff.initials)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(accentColor)
                    }
                    VStack(spacing: 4) {
                        Text(staff.name)
                            .font(.title2.weight(.bold))

                        HStack(spacing: 6) {
                            Image(systemName: staff.role == .driver ? "steeringwheel" : "person.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(staff.role.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                        }

                        if let status = staff.status {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(statusColor(status))
                                    .frame(width: 8, height: 8)
                                Text(status.displayName)
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(statusColor(status))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(statusColor(status).opacity(0.12))
                            .clipShape(Capsule())
                            .padding(.top, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            // ── 2. STAFF INFORMATION ───────────────────────
            Section(header: Text("Staff Information").foregroundColor(.primary)) {
                LabeledContent {
                    Text(String(staff.user_id.prefix(8).uppercased()))
                } label: {
                    Label("Staff ID", systemImage: "person.text.rectangle")
                }
                LabeledContent {
                    Text(staff.email)
                } label: {
                    Label("Email", systemImage: "envelope")
                }
                if let phone = staff.phone_no, !phone.isEmpty {
                    LabeledContent {
                        Text(phone)
                    } label: {
                        Label("Phone", systemImage: "phone")
                    }
                }
                if let cname = creatorName {
                    LabeledContent {
                        Text(cname)
                    } label: {
                        Label("Created By", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }

            // ── 3. LICENSE & COMPLIANCE ──────────────────────────
            if staff.role == .driver {
                Section(header: Text("License & Compliance").foregroundColor(.primary)) {
                    if isLoadingDriver {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 6)
                            Text("Loading license…")
                                .foregroundColor(.secondary)
                        }
                    } else if let d = driverDetails {
                        LabeledContent {
                            Text(d.license_no).font(.body.monospaced())
                        } label: {
                            Label("License No", systemImage: "lanyardcard")
                        }
                        HStack {
                            Label("Expiry Date", systemImage: "calendar.badge.exclamationmark")
                            Spacer()
                            let expiryText  = formatDateString(d.license_expiry)
                            let isExpiringSoon = isExpiringSoon(d.license_expiry)
                            Text(expiryText)
                                .foregroundColor(isExpiringSoon ? .red : .primary)
                                .fontWeight(isExpiringSoon ? .semibold : .regular)
                            if isExpiringSoon {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    } else {
                        Text(driverError ?? "No license record found")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }

            // ── 6. PERFORMANCE DASHBOARD (completed trips only) ────────────────────
            if staff.role == .driver {
                if isLoadingDriver {
                    Section(header: Text("Performance Dashboard").foregroundColor(.primary)) {
                        HStack {
                            ProgressView().padding(.trailing, 6)
                            Text("Loading stats…").foregroundColor(.secondary)
                        }
                    }
                } else if tripStats.totalTrips > 0 {
                    Section(header: Text("Performance Dashboard").foregroundColor(.primary)) {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(spacing: 6) {
                                    Image(systemName: "map.fill")
                                        .font(.title2)
                                        .foregroundColor(accentColor.opacity(0.8))
                                    Text("\(tripStats.totalTrips)")
                                        .font(.title.weight(.bold))
                                        .foregroundColor(.primary)
                                    Text("Completed")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                                .frame(maxWidth: .infinity)

                                Divider()

                                VStack(spacing: 6) {
                                    Image(systemName: "ruler.fill")
                                        .font(.title2)
                                        .foregroundColor(accentColor.opacity(0.8))
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text(formatDistanceNum(tripStats.totalDistance))
                                            .font(.title.weight(.bold))
                                            .foregroundColor(.primary)
                                        Text("km")
                                            .font(.callout.weight(.bold))
                                            .foregroundColor(.secondary)
                                    }
                                    Text("Distance")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 8)

                            Divider()

                            if let lastDate = tripStats.lastTripDate {
                                HStack {
                                    Text("Last Completed Trip")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatDate(lastDate))
                                        .font(.subheadline.weight(.semibold))
                                }
                            }

                            if !recentTrips.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Recent Distances (km)")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                        .padding(.top, 8)

                                    Chart {
                                        let trips = Array(recentTrips.prefix(5).reversed())
                                        ForEach(Array(zip(trips.indices, trips)), id: \.1.trip_id) { index, trip in
                                            let km = trip.distance_travelled ?? 0
                                            let dateStr = trip.start_time.flatMap { formatShortDate($0) } ?? ""
                                            let label = "Trip \(index + 1)|\(dateStr)"

                                            BarMark(
                                                x: .value("Trip", label),
                                                y: .value("Distance (km)", km)
                                            )
                                            .foregroundStyle(Color.blue.gradient)
                                            .cornerRadius(6)
                                            .annotation(position: .top) {
                                                Text(formatDistanceNum(km))
                                                    .font(.caption2.bold())
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .frame(height: 180)
                                    .chartXAxis {
                                        AxisMarks { value in
                                            AxisValueLabel {
                                                if let label = value.as(String.self) {
                                                    let parts = label.split(separator: "|")
                                                    if parts.count == 2 {
                                                        VStack(spacing: 2) {
                                                            Text(String(parts[0]))
                                                                .font(.caption2.weight(.medium))
                                                                .foregroundColor(.primary)
                                                            Text(String(parts[1]))
                                                                .font(.system(size: 10))
                                                                .foregroundColor(.secondary)
                                                        }
                                                    } else {
                                                        Text(label)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks(position: .leading) {
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                            AxisValueLabel()
                                        }
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    // No completed trips yet
                    Section(header: Text("Performance Dashboard").foregroundColor(.primary)) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("No completed trips yet")
                                    .font(.subheadline.weight(.medium))
                                Text("Stats will appear once a trip is marked as completed.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            } else {
                Section(header: Text("Overview").foregroundColor(.primary)) {
                    LabeledContent {
                        Text(staff.role.displayName)
                    } label: {
                        Label("Role", systemImage: "person.text.rectangle")
                    }
                }
            }

            // ── 4. CURRENT STATUS ─────────────────────────────
            if staff.role == .driver {
                Section(header: Text("Live Status").foregroundColor(.primary)) {
                    if let trip = activeTrip {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 10, height: 10)
                                    Text("On Trip")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.green)
                                }
                                Spacer()
                                statusBadge(trip.status ?? "ongoing")
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text(trip.trip_name ?? "Unnamed Trip")
                                    .font(.headline)

                                if let origin = trip.origin, let dest = trip.destination {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(spacing: 4) {
                                            Image(systemName: "record.circle")
                                                .font(.system(size: 12))
                                                .foregroundColor(.blue)
                                            Rectangle()
                                                .fill(Color.secondary.opacity(0.3))
                                                .frame(width: 2, height: 20)
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.red)
                                        }
                                        .padding(.top, 4)

                                        VStack(alignment: .leading, spacing: 16) {
                                            Text(shortAddress(origin))
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Text(shortAddress(dest))
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    } else {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Available")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Driver is currently idle")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── 5. CURRENT VEHICLE ────────────────────────────
                Section(header: Text("Assigned Vehicle").foregroundColor(.primary)) {
                    if let vehicle = vehicleInfo {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(accentColor.opacity(0.1))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "car.fill")
                                    .font(.title2)
                                    .foregroundColor(accentColor)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(vehicle.number_plate)
                                    .font(.subheadline.weight(.semibold).monospaced())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                    )
                                    .cornerRadius(4)

                                if let vname = vehicle.vehicle_name {
                                    Text(vname)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if let vtype = vehicle.vehicle_type {
                                VStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(vtype)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 6)
                    } else {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "car")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("No Assigned Vehicle")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("No trip has been assigned to this driver yet.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // ── 7. RECENT TRIPS ────────────────────
            if staff.role == .driver && !recentTrips.isEmpty {
                Section(header: Text("Recent Activity").foregroundColor(.primary)) {
                    ForEach(recentTrips, id: \.trip_id) { trip in
                        HStack(spacing: 16) {
                            let statusRaw = trip.status?.lowercased() ?? "unknown"
                            let style = tripStatusStyle(statusRaw)

                            ZStack {
                                Circle()
                                    .fill(style.bg.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: statusIcon(statusRaw))
                                    .font(.title3)
                                    .foregroundColor(style.fg)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(trip.trip_name ?? "Unnamed Trip")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                    if let dist = trip.distance_travelled {
                                        Text(formatDistance(dist))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.primary)
                                    }
                                }

                                if let origin = trip.origin, let dest = trip.destination {
                                    HStack(spacing: 6) {
                                        Text(shortAddress(origin))
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary.opacity(0.7))
                                        Text(shortAddress(dest))
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                }

                                HStack {
                                    if let start = trip.start_time {
                                        Text(formatTimestamp(start))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    statusBadge(statusRaw)
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

            // ── MAINTENANCE SECTIONS ──────────────────────────
            if staff.role == .maintenance {
                // 1. PERFORMANCE
                Section(header: Text("Performance").foregroundColor(.primary)) {
                    if isLoadingMaintenance {
                        HStack {
                            ProgressView().padding(.trailing, 6)
                            Text("Loading maintenance data…").foregroundColor(.secondary)
                        }
                    } else if let error = maintenanceError {
                        Text(error).foregroundColor(.red).font(.subheadline)
                    } else {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(spacing: 6) {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .font(.title2)
                                        .foregroundColor(accentColor.opacity(0.8))
                                    Text("\(workStats.completedOrders)")
                                        .font(.title.weight(.bold))
                                        .foregroundColor(.primary)
                                    Text("Completed")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                                .frame(maxWidth: .infinity)

                                Divider()

                                VStack(spacing: 6) {
                                    Image(systemName: "clock.fill")
                                        .font(.title2)
                                        .foregroundColor(accentColor.opacity(0.8))
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Text(formatDistanceNum(workStats.totalHours))
                                            .font(.title.weight(.bold))
                                            .foregroundColor(.primary)
                                        Text("hrs")
                                            .font(.callout.weight(.bold))
                                            .foregroundColor(.secondary)
                                    }
                                    Text("Time Worked")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                                .frame(maxWidth: .infinity)

                                Divider()

                                VStack(spacing: 6) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(accentColor.opacity(0.8))
                                    Text("₹\(formatDistanceNum(workStats.totalCost))")
                                        .font(.title.weight(.bold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.4)
                                        .frame(maxWidth: .infinity)
                                    Text("Est. Cost")
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 8)

                            Divider()

                            if let lastDate = lastActivityDate {
                                HStack {
                                    Text("Last Activity")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatDate(lastDate))
                                        .font(.subheadline.weight(.semibold))
                                }
                            }

                            // Task & Issues summary
                            HStack(spacing: 12) {
                                // Tasks Progress
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tasks Done")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Text("\(taskSummary.completed) of \(taskSummary.total)")
                                        .font(.title3.weight(.bold))
                                        .foregroundColor(accentColor)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(8)

                                // Parts Usage
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Parts Usage")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Text("₹\(formatDistanceNum(partsCost))")
                                        .font(.title3.weight(.bold))
                                        .foregroundColor(accentColor)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // 2. CURRENT WORK
                Section(header: Text("Current Work").foregroundColor(.primary)) {
                    if let workOrder = activeWorkOrder {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label {
                                    Text("Active Work Order")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(accentColor)
                                } icon: {
                                    Image(systemName: "hammer.fill")
                                        .foregroundColor(accentColor)
                                }
                                Spacer()
                                maintenanceStatusBadge(workOrder.status ?? "pending")
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(workOrder.issue_title)
                                    .font(.headline)

                                HStack {
                                    if let priority = workOrder.priority {
                                        Text(priority.uppercased())
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(priorityColor(priority))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(priorityColor(priority).opacity(0.15))
                                            .cornerRadius(4)
                                    }

                                    if let vehicle = activeWorkOrderVehicle {
                                        Text(vehicle.number_plate)
                                            .font(.caption.monospaced())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "cup.and.saucer.fill")
                                    .foregroundColor(.gray)
                            }
                            Text("No active work orders")
                                .foregroundColor(.secondary)
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.vertical, 4)
                    }
                }

                // 3. ISSUES SNAPSHOT
                Section(header: Text("Issues Snapshot").foregroundColor(.primary)) {
                    HStack(spacing: 20) {
                        issueStatItem(title: "Pending", count: issueSummary.pending)
                        issueStatItem(title: "In Progress", count: issueSummary.inProgress)
                        issueStatItem(title: "Completed", count: issueSummary.completed)
                    }
                    .padding(.vertical, 8)
                }

                // 4. RECENT WORK ORDERS
                if !recentWorkOrders.isEmpty {
                    Section(header: Text("Recent Work Orders").foregroundColor(.primary)) {
                        ForEach(recentWorkOrders, id: \.work_order_id) { order in
                            HStack(spacing: 16) {
                                let statusRaw = order.status?.lowercased() ?? "unknown"

                                ZStack {
                                    Circle()
                                        .fill(maintenanceStatusColor(statusRaw).opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: maintenanceStatusIcon(statusRaw))
                                        .font(.title3)
                                        .foregroundColor(maintenanceStatusColor(statusRaw))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(order.issue_title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        if let priority = order.priority {
                                            Text(priority.uppercased())
                                                .font(.caption2.weight(.bold))
                                                .foregroundColor(priorityColor(priority))
                                        }
                                    }

                                    HStack {
                                        if let start = order.created_at {
                                            Text(formatTimestamp(start))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        maintenanceStatusBadge(order.status ?? "unknown")
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }

            // ── 8. ACTIONS ──────────────────────────────────
            Section {
                Button(role: .destructive) {
                    showDeactivateConfirmation = true
                } label: {
                    if isDeactivating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Deactivate Staff Account")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isDeactivating || staff.status == .inactive)
            }
        }
        // Existing alerts (unchanged)
        .alert(
            "Deactivate Account?",
            isPresented: $showDeactivateConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                Task { await deactivateStaff() }
            }
        } message: {
            Text("Are you sure you want to deactivate \(staff.name)'s account?")
        }
        .alert("Error Deactivating", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred.")
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchCreatorName()
            if staff.role == .driver {
                await fetchDriverDetails()
            } else if staff.role == .maintenance {
                await fetchMaintenanceDetails()
            }
        }
    }

    // MARK: - Status badge helper
    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        let (bg, fg, label) = tripStatusStyle(status)
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundColor(fg)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(bg.opacity(0.15))
            .clipShape(Capsule())
    }

    private func tripStatusStyle(_ raw: String) -> (bg: Color, fg: Color, label: String) {
        switch raw.lowercased() {
        case "completed":                        return (.green,  .green,  "Completed")
        case "ongoing", "in_transit":            return (.blue,   .blue,   "In Transit")
        case "in_progress":                      return (.blue,   .blue,   "In Progress")
        case "assigned", "scheduled":            return (.orange, .orange, "Assigned")
        case "cancelled", "canceled":            return (.red,    .red,    "Cancelled")
        default:                                 return (.gray,   .gray,   raw.capitalized)
        }
    }

    private func statusIcon(_ raw: String) -> String {
        switch raw.lowercased() {
        case "completed":                     return "checkmark.circle.fill"
        case "ongoing", "in_transit":         return "location.circle.fill"
        case "in_progress":                   return "arrow.triangle.2.circlepath.circle.fill"
        case "assigned", "scheduled":         return "clock.fill"
        case "cancelled", "canceled":         return "xmark.circle.fill"
        default:                              return "questionmark.circle.fill"
        }
    }

    // MARK: - Fetch: creator name (unchanged logic)
    private func fetchCreatorName() async {
        guard let creatorId = staff.created_by, creatorName == nil else { return }
        do {
            let records: [CreatorRecord] = try await SupabaseManager.shared.client
                .from("users")
                .select("name")
                .eq("user_id", value: creatorId)
                .limit(1)
                .execute()
                .value
            if let fetchedName = records.first?.name {
                await MainActor.run { self.creatorName = fetchedName }
            }
        } catch {
            print("Failed to fetch creator name: \(error)")
        }
    }

    // MARK: - Fetch: driver details → license
    private func fetchDriverDetails() async {
        await MainActor.run { isLoadingDriver = true }
        do {
            // Step 1: get driver row by user_id
            let drivers: [DriverRecord] = try await SupabaseManager.shared.client
                .from("drivers")
                .select("driver_id, license_no, license_expiry")
                .eq("user_id", value: staff.user_id)
                .limit(1)
                .execute()
                .value

            guard let driver = drivers.first else {
                await MainActor.run {
                    self.driverError  = "No driver record found"
                    self.isLoadingDriver = false
                }
                return
            }

            await MainActor.run { self.driverDetails = driver }

            // Step 2: fetch trip stats + active trip + recent trips
            await fetchTripStats(driverId: driver.driver_id)
            await fetchActiveTrip(driverId: driver.driver_id)
            await fetchRecentTrips(driverId: driver.driver_id)

            await MainActor.run { self.isLoadingDriver = false }
        } catch {
            await MainActor.run {
                self.driverError     = error.localizedDescription
                self.isLoadingDriver = false
            }
        }
    }

    // MARK: - Fetch: trip stats (completed trips, total distance, last trip)
    private func fetchTripStats(driverId: String) async {
        do {
            // Only count completed trips for performance metrics
            let rows: [DriverTripRow] = try await SupabaseManager.shared.client
                .from("trips")
                .select("trip_id, distance_travelled, start_time, end_time, status")
                .eq("driver_id", value: driverId)
                .eq("status", value: "completed")
                .execute()
                .value

            var stats = TripStats()
            var latestDate: Date? = nil

            for row in rows {
                stats.totalTrips    += 1
                stats.totalDistance += row.distance_travelled ?? 0

                let dateStr = row.end_time ?? row.start_time
                if let dStr = dateStr, let d = parseTimestamp(dStr) {
                    if latestDate == nil || d > latestDate! {
                        latestDate = d
                    }
                }
            }
            stats.lastTripDate = latestDate

            await MainActor.run { self.tripStats = stats }
        } catch {
            print("fetchTripStats error: \(error)")
        }
    }

    // MARK: - Fetch: active trip (mirrors DriverDashboardViewModel — no server-side status filter)
    private func fetchActiveTrip(driverId: String) async {
        // Active statuses (same set used by DriverDashboardViewModel's TripMap init)
        let activeStatuses: Set<String> = [
            "assigned", "planned", "upcoming", "scheduled",   // → .planned
            "active", "in_progress", "inprogress", "started", // → .inProgress
            "ongoing", "in_transit"                            // extra live statuses
        ]

        do {
            // Fetch all trips for this driver (same as DriverDashboardViewModel)
            let rows: [DriverTripRow] = try await SupabaseManager.shared.client
                .from("trips")
                .select("trip_id, trip_name, origin, destination, distance_travelled, start_time, end_time, status, vehicle_id")
                .eq("driver_id", value: driverId)
                .order("start_time", ascending: false)
                .limit(20)
                .execute()
                .value

            print("🚗 All trips fetched: \(rows.count), statuses: \(rows.map { $0.status ?? "nil" })")

            // Client-side: pick the most recent active/upcoming trip
            let trip = rows.first { row in
                let s = (row.status ?? "").lowercased()
                return activeStatuses.contains(s)
            }

            await MainActor.run { self.activeTrip = trip }
            print("🟢 Active trip: \(trip?.trip_id ?? "none"), vehicle_id: \(trip?.vehicle_id ?? "none")")

            // Fetch vehicle from the active trip if it has one
            if let vehicleId = trip?.vehicle_id, !vehicleId.isEmpty {
                await fetchVehicleInfo(vehicleId: vehicleId)
            } else {
                // Fallback: check any trip with a vehicle_id (most recent assigned)
                if let fallbackTrip = rows.first(where: { $0.vehicle_id != nil && !($0.vehicle_id ?? "").isEmpty }),
                   let vehicleId = fallbackTrip.vehicle_id {
                    print("🔄 Fallback vehicle from trip: \(fallbackTrip.trip_id)")
                    await fetchVehicleInfo(vehicleId: vehicleId)
                }
            }
        } catch {
            print("fetchActiveTrip error: \(error)")
        }
    }


    // MARK: - Fetch: recent completed trips (last 5 for chart)
    private func fetchRecentTrips(driverId: String) async {
        do {
            let rows: [DriverTripRow] = try await SupabaseManager.shared.client
                .from("trips")
                .select("trip_id, trip_name, origin, destination, distance_travelled, start_time, end_time, status, vehicle_id")
                .eq("driver_id", value: driverId)
                .eq("status", value: "completed")
                .order("end_time", ascending: false)
                .limit(5)
                .execute()
                .value

            await MainActor.run { self.recentTrips = rows }
        } catch {
            print("fetchRecentTrips error: \(error)")
        }
    }

    // MARK: - Fetch: vehicle info
    private func fetchVehicleInfo(vehicleId: String) async {
        do {
            let rows: [VehicleRow] = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("vehicle_id, number_plate, vehicle_type, vehicle_name")
                .eq("vehicle_id", value: vehicleId)
                .limit(1)
                .execute()
                .value

            await MainActor.run { self.vehicleInfo = rows.first }
        } catch {
            print("fetchVehicleInfo error: \(error)")
        }
    }

    // MARK: - Deactivate (unchanged)
    private func deactivateStaff() async {
        await MainActor.run { isDeactivating = true }
        do {
            try await SupabaseManager.shared.client
                .from("users")
                .update(["status": "inactive"])
                .eq("user_id", value: staff.user_id)
                .execute()

            await MainActor.run {
                isDeactivating = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.errorMessage  = error.localizedDescription
                self.showAlert     = true
                self.isDeactivating = false
            }
        }
    }
    // MARK: - Maintenance Fetch Logic

    private func fetchMaintenanceDetails() async {
        await MainActor.run { isLoadingMaintenance = true }

        let woIds = await fetchWorkOrders()

        async let partsFetch: () = fetchPartsUsage(workOrderIds: woIds)
        async let issuesFetch: () = fetchIssuesSummary()

        _ = await (partsFetch, issuesFetch)

        await MainActor.run { isLoadingMaintenance = false }
    }

    private func fetchWorkOrders() async -> [String] {
        var ids: [String] = []
        do {
            let rows: [WorkOrderRow] = try await SupabaseManager.shared.client
                .from("work_orders")
                .select("work_order_id, issue_title, priority, status, vehicle_id, created_at, updated_at, hours_worked, est_cost")
                .eq("maintenance_personnel_id", value: staff.user_id)
                .order("created_at", ascending: false)
                .execute()
                .value

            ids = rows.map { $0.work_order_id }
            var activeWO: WorkOrderRow? = nil
            var stats = WorkStats()
            var recent: [WorkOrderRow] = []
            var latestDate: Date? = nil

            for row in rows {
                let status = row.status?.lowercased() ?? ""
                if activeWO == nil && (status == "pending" || status == "in progress") {
                    activeWO = row
                }

                if status == "completed" {
                    stats.completedOrders += 1
                }
                stats.totalHours += row.hours_worked ?? 0
                stats.totalCost += row.est_cost ?? 0

                if let uStr = row.updated_at, let d = parseTimestamp(uStr) {
                    if latestDate == nil || d > latestDate! {
                        latestDate = d
                    }
                }
            }

            recent = Array(rows.prefix(5))

            await MainActor.run {
                self.activeWorkOrder = activeWO
                self.workStats = stats
                self.recentWorkOrders = recent
                self.lastActivityDate = latestDate
            }

            if let wId = activeWO?.work_order_id {
                await fetchTasksSummary(workOrderId: wId)
            }

            if let vId = activeWO?.vehicle_id {
                await fetchMaintenanceVehicleInfo(vehicleId: vId)
            }
        } catch {
            await MainActor.run { self.maintenanceError = error.localizedDescription }
            print("fetchWorkOrders error: \(error)")
        }
        return ids
    }

    private func fetchTasksSummary(workOrderId: String) async {
        do {
            let tasks: [TaskRow] = try await SupabaseManager.shared.client
                .from("work_order_tasks")
                .select("task_id, description, is_completed")
                .eq("work_order_id", value: workOrderId)
                .execute()
                .value

            var summary = TaskSummary()
            summary.total = tasks.count
            summary.completed = tasks.filter { $0.is_completed == true }.count
            await MainActor.run { self.taskSummary = summary }
        } catch {
            print("fetchTasksSummary error: \(error)")
        }
    }

    private func fetchMaintenanceVehicleInfo(vehicleId: String) async {
        do {
            let rows: [VehicleRow] = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("vehicle_id, number_plate, vehicle_type, vehicle_name")
                .eq("vehicle_id", value: vehicleId)
                .limit(1)
                .execute()
                .value
            await MainActor.run { self.activeWorkOrderVehicle = rows.first }
        } catch {
            print("fetchMaintenanceVehicleInfo error: \(error)")
        }
    }

    private func fetchPartsUsage(workOrderIds: [String]) async {
        guard !workOrderIds.isEmpty else { return }
        do {
            let parts: [StaffPartRow] = try await SupabaseManager.shared.client
                .from("work_order_parts")
                .select("work_order_id, quantity_required, cost_at_time, inventory_id")
                .in("work_order_id", values: workOrderIds)
                .execute()
                .value

            var total: Double = 0
            for p in parts {
                let q = Double(p.quantity_required ?? 0)
                let c = p.cost_at_time ?? 0
                total += (q * c)
            }

            await MainActor.run { self.partsCost = total }
        } catch {
            print("fetchPartsUsage error: \(error)")
        }
    }

    private func fetchIssuesSummary() async {
        do {
            let issues: [IssueRow] = try await SupabaseManager.shared.client
                .from("maintenance_issues")
                .select("issue_id, status, issue_summary")
                .eq("maintenance_personnel_id", value: staff.user_id)
                .execute()
                .value

            var summary = IssueSummary()
            for issue in issues {
                let s = issue.status?.lowercased() ?? ""
                if s == "pending" { summary.pending += 1 }
                else if s == "in progress" { summary.inProgress += 1 }
                else if s == "completed" || s == "resolved" { summary.completed += 1 }
            }
            await MainActor.run { self.issueSummary = summary }
        } catch {
            print("fetchIssuesSummary error: \(error)")
        }
    }

    // MARK: - Maintenance UI Helpers

    @ViewBuilder
    private func maintenanceStatusBadge(_ raw: String) -> some View {
        let label = raw.capitalized
        let color = maintenanceStatusColor(raw)

        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .textCase(.uppercase)
    }

    private func maintenanceStatusColor(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "completed": return .green
        case "in progress": return .blue
        case "pending": return .orange
        case "cancelled": return .red
        default: return .gray
        }
    }

    private func maintenanceStatusIcon(_ raw: String) -> String {
        switch raw.lowercased() {
        case "completed": return "checkmark.circle.fill"
        case "in progress": return "hammer.fill"
        case "pending": return "clock.fill"
        case "cancelled": return "xmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private func priorityColor(_ raw: String) -> Color {
        switch raw.lowercased() {
        case "high", "urgent": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }

    @ViewBuilder
    private func issueStatItem(title: String, count: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.weight(.bold))
                .foregroundColor(accentColor)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(accentColor.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Colour helpers (unchanged)
    private func statusColor(_ status: AccountStatus) -> Color {
        switch status {
        case .active:   return Color(red: 0.1, green: 0.72, blue: 0.35)
        case .pending:  return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .inactive: return .gray
        }
    }

    // MARK: - Formatting helpers

    /// Parse Supabase timestamps like "2026-04-23 09:46:19" or ISO-8601
    private func parseTimestamp(_ raw: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSSSSS"
        ]
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        for f in formats {
            fmt.dateFormat = f
            if let d = fmt.date(from: raw) { return d }
        }
        return nil
    }

    /// Parse "yyyy-MM-dd" date strings from drivers.license_expiry
    private func parseDateString(_ raw: String) -> Date? {
        let fmt = DateFormatter()
        fmt.locale     = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: raw)
    }

    private func formatDateString(_ raw: String) -> String {
        guard let d = parseDateString(raw) else { return raw }
        return formatDate(d)
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    private func formatTimestamp(_ raw: String) -> String {
        guard let d = parseTimestamp(raw) else { return raw }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: d)
    }

    private func formatShortDate(_ raw: String) -> String {
        guard let d = parseTimestamp(raw) else { return "Trip" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: d)
    }

    /// Returns true when expiry is within 30 days from today
    private func isExpiringSoon(_ raw: String) -> Bool {
        guard let expiry = parseDateString(raw) else { return false }
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        return diff < 30
    }

    /// Format km distance: "127.4 km"
    private func formatDistance(_ km: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        let numStr = formatter.string(from: NSNumber(value: km)) ?? String(format: "%.1f", km)
        return "\(numStr) km"
    }

    private func formatDistanceNum(_ km: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: km)) ?? String(format: "%.1f", km)
    }

    /// Shorten long address to first component
    private func shortAddress(_ address: String) -> String {
        address.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? address
    }
}
