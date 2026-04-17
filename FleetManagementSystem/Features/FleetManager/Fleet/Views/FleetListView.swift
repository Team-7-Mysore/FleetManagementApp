import SwiftUI

struct FleetListView: View {
    @StateObject private var vm = FleetListViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fleet")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Summary Cards
                            SummaryCardView(
                                title: "TOTAL VEHICLES",
                                value: "\(vm.totalVehiclesCount)",
                                trend: vm.trendText,
                                trendColor: .green
                            )
                            .padding(.horizontal)
                            
                            
                            
                            // Vehicle List
                            if vm.isLoading {
                                ProgressView()
                                    .padding()
                            } else if let errorMessage = vm.errorMessage {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 52))
                                        .foregroundColor(.orange)
                                    Text("Could Not Load Vehicles")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(errorMessage)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.top, 40)
                                .padding(.horizontal)
                            } else if vm.vehicles.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "truck.box.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(Color(.systemGray4))
                                    Text("No Vehicles Added")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("Click the + button to add your first vehicle.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 40)
                            } else {
                                ForEach(vm.vehicles) { vehicle in
                                    VehicleCardView(vehicle: vehicle)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
                
                // Floating Action Button
                NavigationLink(destination: AddVehicleView(fleetVM: vm)){
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.TechBlue)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .zIndex(1)
            }
            .navigationBarHidden(true) // We use our custom header
            .onAppear {
                Task {
                    await vm.fetchVehicles()
                }
            }
        }
    }
}

struct SummaryCardView: View {
    let title: String
    let value: String
    let trend: String
    let trendColor: Color
    var showProgress: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.TechBlue)
                .tracking(1.2)
            
            Text(value)
                .font(.system(size: 40, weight: .black))
                .foregroundColor(.black)
            
            if showProgress {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                            .overlay(
                                Capsule()
                                    .fill(Color.green)
                                    .frame(width: geo.size.width * 0.8, height: 4),
                                alignment: .leading
                            )
                    }
                    .frame(height: 4)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .semibold))
                    Text(trend)
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(trendColor)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(30)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}



struct VehicleCardView: View {
    let vehicle: Vehicle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Vehicle Image (Placeholder)
            ZStack {
                if let urlString = vehicle.imageURL,
                   let url = URL(string: urlString) {
                    
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ZStack {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 180)
                            
                            ProgressView()
                        }
                    }
                    .frame(height: 180)
                    .clipped()
                    
                } else {

                    ZStack {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 180)
                        
                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                }
            }
            .cornerRadius(20)
            
            VStack(alignment: .leading, spacing: 16) {
                // Asset ID
                VStack(alignment: .leading, spacing: 4) {
                    Text("ASSET ID")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(vehicle.registrationNumber)
                        .font(.system(size: 16, weight: .bold))
                }
                
                // Name, Model, Brand
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.name)
                        .font(.system(size: 18, weight: .bold))
                    
                    let details = [vehicle.brand, vehicle.model]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    
                    if !details.isEmpty {
                        Text(details)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                
                // Buttons
                HStack(spacing: 12) {
                    NavigationLink(destination: VehicleDetailView(vehicleId: vehicle.id)) {
                        Text("Details")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: {}) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.TechBlue)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(20)
        }
        .background(Color.white)
        .cornerRadius(30)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    FleetListView()
}
