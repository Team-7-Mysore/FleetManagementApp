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
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                Text("SDV Diagnostics Sequence")
                    .font(.headline)
                    .padding(.top, 20)
                
                // Scanner Area
                ZStack(alignment: .top) {
                    // Grid background
                    gridBackground
                    
                    // Vehicle Wireframe
                    Image(systemName: "truck.box.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.primaryGreen.opacity(0.6), AppTheme.darkGreen],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: AppTheme.primaryGreen.opacity(0.4), radius: 10, x: 0, y: 0)
                        .padding(.top, 60)
                    
                    // Scanning Laser
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, AppTheme.mintGreen, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 4)
                        .shadow(color: AppTheme.mintGreen, radius: 8, x: 0, y: 0)
                        .offset(y: scanProgress)
                        .opacity(isComplete ? 0 : 1)
                        .padding(.horizontal, 40)
                }
                .frame(height: 260)
                .background(Color.black.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(AppTheme.primaryGreen.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                
                // Checklist
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(checks.indices, id: \.self) { index in
                            checkRow(for: checks[index], at: index)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                // Footer / Button
                if isComplete {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: fetchedReports.isEmpty ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                .font(.title3)
                                .foregroundStyle(fetchedReports.isEmpty ? AppTheme.primaryGreen : AppTheme.statusDanger)
                            Text(fetchedReports.isEmpty ? "All Systems Verified" : "\(fetchedReports.count) Issues Detected")
                                .font(.headline)
                                .foregroundStyle(fetchedReports.isEmpty ? AppTheme.primaryGreen : AppTheme.statusDanger)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            (fetchedReports.isEmpty ? AppTheme.primaryGreen : AppTheme.statusDanger).opacity(0.1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        .padding(.horizontal)
                        
                        Button {
                            Task { await submitAutoInspection() }
                        } label: {
                            Text("Complete Diagnostics")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .task {
            await fetchDiagnostics()
        }
        .onAppear(perform: startScans)
    }

    private var gridBackground: some View {
        GeometryReader { geo in
            Path { path in
                let step: CGFloat = 20
                for x in stride(from: 0, to: geo.size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                for y in stride(from: 0, to: geo.size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(AppTheme.primaryGreen.opacity(0.15), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func checkRow(for checkName: String, at index: Int) -> some View {
        let isChecked = completedChecks.contains(checkName)
        let hasFault = fetchedReports.contains(where: { report in
            if report.category == "mechanical" && checkName.contains("Engine") { return true }
            if report.category == "body damage" && checkName.contains("Lighting") { return true }
            return false
        })
        
        let statusColor = !isChecked ? Color.secondary.opacity(0.3) : (hasFault ? AppTheme.statusDanger : AppTheme.primaryGreen)
        let iconName = !isChecked ? "hourglass" : (hasFault ? "xmark.circle.fill" : "checkmark.circle.fill")
        
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(statusColor)
                    // Apply rotation only if we are scanning this item
                    .rotationEffect(.degrees((!isChecked && completedChecks.count == index) ? 180 : 0))
                    .animation((!isChecked && completedChecks.count == index) ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: completedChecks.count == index)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(checkName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isChecked ? .primary : .secondary)
                
                Text(isChecked ? (hasFault ? "Fault Detected" : "Verified") : (completedChecks.count == index ? "Scanning..." : "Pending..."))
                    .font(.caption)
                    .foregroundStyle(isChecked ? statusColor : .secondary)
            }
            
            Spacer()
            
            if isChecked {
                Text("OK")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Capsule())
                    .opacity(hasFault ? 0 : 1)
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: AppTheme.cardShadowColor, radius: 4, x: 0, y: 2)
        .opacity(completedChecks.count >= index ? 1 : 0.4)
        .animation(.easeIn, value: completedChecks.count)
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
