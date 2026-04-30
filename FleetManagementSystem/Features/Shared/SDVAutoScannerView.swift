import SwiftUI
import Supabase

struct SDVAutoScannerView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Config
    let vehicleId: UUID
    let inspectionType: InspectionType
    let onCompletion: ([DriverReportDTO]) -> Void
    
    // State
    @State private var scanProgress: CGFloat = 0.0
    @State private var isComplete = false
    @State private var completedChecks: [String] = []
    @State private var fetchedReports: [DriverReportDTO] = []
    
    // Checks list
    let checks = [
        "Network Ping",
        "Tire Pressure Sensors",
        "Lighting System Relay",
        "Engine Diagnostics (OBD2)",
        "Brake Fluid Pressure",
        "Fuel / Battery Sensor",
        "Seatbelt Tensioners"
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            Text("SDV Diagnostics Sequence")
                .font(.headline)
            
            // Wireframe representation of a vehicle
            ZStack(alignment: .top) {
                Image(systemName: "car.top.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 250)
                    .foregroundColor(Color.blue.opacity(0.3))
                
                // Scanning Laser
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .cyan, .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 10)
                    .offset(y: scanProgress)
                    .opacity(isComplete ? 0 : 1)
            }
            .frame(height: 250)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(checks.indices, id: \.self) { index in
                    let checkName = checks[index]
                    let isChecked = completedChecks.contains(checkName)
                    let hasFault = fetchedReports.contains(where: { report in
                        if report.category == "mechanical" && checkName.contains("Engine") { return true }
                        if report.category == "body damage" && checkName.contains("Lighting") { return true }
                        return false
                    })
                    
                    HStack {
                        Image(systemName: !isChecked ? "circle.dashed" : (hasFault ? "xmark.circle.fill" : "checkmark.circle.fill"))
                            .foregroundColor(!isChecked ? .gray : (hasFault ? .red : .green))
                        Text(checkName)
                            .font(.subheadline)
                            .foregroundColor(!isChecked ? .secondary : (hasFault ? .red : .primary))
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 40)
            
            if isComplete {
                HStack {
                    Image(systemName: fetchedReports.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(fetchedReports.isEmpty ? .green : .red)
                    Text(fetchedReports.isEmpty ? "All Systems Go" : "\(fetchedReports.count) Issues Detected")
                        .fontWeight(.bold)
                }
                .padding()
                .background(fetchedReports.isEmpty ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(10)
                
                Button(action: {
                    Task { await submitAutoInspection() }
                }) {
                    Text("Submit & Proceed")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .task {
            await fetchDiagnostics()
        }
        .onAppear(perform: startScans)
    }
    
    private func fetchDiagnostics() async {
        do {
            // Fetch any reported/pending issues for this vehicle
            fetchedReports = try await SupabaseManager.shared.client
                .from("driver_reports")
                .select()
                .eq("vehicle_id", value: vehicleId.uuidString)
                .in("status", value: ["reported", "pending"])
                .execute()
                .value
        } catch {
            print("Failed to fetch diagnostics: \(error)")
        }
    }
    
    private func startScans() {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: true)) {
            scanProgress = 250 // the height of the image frame
        }
        
        let totalDuration: Double = 4.0
        let stepDuration = totalDuration / Double(checks.count)
        
        for (index, checkItem) in checks.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index + 1) * stepDuration)) {
                completedChecks.append(checkItem)
                
                if index == checks.count - 1 {
                    isComplete = true
                    scanProgress = 0 // halt animation effect
                }
            }
        }
    }
    
    private func submitAutoInspection() async {
        onCompletion(fetchedReports)
        dismiss()
    }
}
