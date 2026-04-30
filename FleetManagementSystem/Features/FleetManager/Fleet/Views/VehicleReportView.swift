import SwiftUI
import UniformTypeIdentifiers
import Combine
internal import PostgREST
import Supabase

// Struct mapping to the Supabase RPC call "get_vehicle_report"
struct VehicleReportData: Decodable {
    let totalTrips: Int
    let distanceTravelled: Double?
    let fuelCost: Double?
    let fuelVolume: Double?
    let reportedIssues: [ReportedIssue]?
    
    enum CodingKeys: String, CodingKey {
        case totalTrips = "total_trips"
        case distanceTravelled = "distance_travelled"
        case fuelCost = "fuel_cost"
        case fuelVolume = "fuel_volume"
        case reportedIssues = "reported_issues"
    }
}

struct ReportedIssue: Decodable, Identifiable {
    let id: UUID
    let category: String
    let severity: String
    let description: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case category
        case severity
        case description
        case createdAt = "created_at"
    }
}

@MainActor
class VehicleReportViewModel: ObservableObject {
    @Published var data: VehicleReportData?
    @Published var isLoading = false
    @Published var dateRange: ClosedRange<Date> = Date.distantPast...Date.distantFuture
    @Published var error: String?
    
    let vehicleId: UUID
    
    init(vehicleId: UUID) {
        self.vehicleId = vehicleId
    }
    
    func generateReport(start: Date, end: Date) async {
        self.isLoading = true
        self.error = nil
        do {
            let params: [String: AnyValue] = [
                "target_vehicle_id": .uuid(vehicleId),
                "start_date": .string(ISO8601DateFormatter().string(from: start)),
                "end_date": .string(ISO8601DateFormatter().string(from: end))
            ]
            let reportData: VehicleReportData = try await SupabaseManager.shared.client
                .rpc("get_vehicle_report", params: params)
                .execute()
                .value
            
            self.data = reportData
        } catch {
            self.error = error.localizedDescription
        }
        self.isLoading = false
    }
}

// Swift Supabase extension shim for parameter packing since SDK types differ slightly
enum AnyValue: Encodable {
    case string(String)
    case uuid(UUID)
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .uuid(let u): try container.encode(u)
        }
    }
}

struct VehicleReportView: View {
    @StateObject private var viewModel: VehicleReportViewModel
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var endDate = Date()
    
    init(vehicleId: UUID) {
        _viewModel = StateObject(wrappedValue: VehicleReportViewModel(vehicleId: vehicleId))
    }
    
    var body: some View {
        Form {
            Section("Timeframe") {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                
                Button("Run RPC Report") {
                    Task {
                        await viewModel.generateReport(start: startDate, end: endDate)
                    }
                }
                .disabled(viewModel.isLoading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let error = viewModel.error {
                Text(error).foregroundColor(.red)
            } else if let data = viewModel.data {
                reportSummarySection(data: data)
            }
        }
        .navigationTitle("Vehicle Report")
    }
    
    @ViewBuilder
    private func reportSummarySection(data: VehicleReportData) -> some View {
        Section("Snapshot Metrics") {
            HStack {
                Text("Total Trips")
                Spacer()
                Text("\(data.totalTrips)")
                    .bold()
            }
            HStack {
                Text("Distance Travelled")
                Spacer()
                Text(String(format: "%.1f km", data.distanceTravelled ?? 0))
                    .bold()
            }
            HStack {
                Text("Fuel Usage")
                Spacer()
                Text(String(format: "%.1f gal", data.fuelVolume ?? 0))
                    .bold()
            }
            HStack {
                Text("Total Fuel Cost")
                Spacer()
                Text(String(format: "$%.2f", data.fuelCost ?? 0))
                    .bold()
            }
        }
        
        Section("Issues Triggered (\(data.reportedIssues?.count ?? 0))") {
            if let issues = data.reportedIssues, !issues.isEmpty {
                ForEach(issues) { issue in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(issue.category.capitalized)
                                .font(.headline)
                            Spacer()
                            Text(issue.severity.uppercased())
                                .font(.caption)
                                .padding(4)
                                .background(severityColor(issue.severity).opacity(0.2))
                                .foregroundColor(severityColor(issue.severity))
                                .cornerRadius(4)
                        }
                        Text(issue.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No issues reported in this timeframe.")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "low": return .green
        case "medium": return .orange
        case "critical": return .red
        default: return .gray
        }
    }
}
