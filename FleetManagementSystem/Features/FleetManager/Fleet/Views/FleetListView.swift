import SwiftUI

struct FleetListView: View {
    @StateObject private var vm = FleetListViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // 🔷 Content
                ScrollView {
                    VStack(spacing: 16) {
                        
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
                                
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                            .padding(.horizontal)
                            
                        } else if vm.vehicles.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                Text("No Vehicles")
                                    .font(.headline)
                                
                                Text("Add vehicles to see them here.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
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
                
                // 🔥 Floating Add Button
                NavigationLink(destination: AddVehicleView(fleetVM: vm)) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle("Fleet")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if vm.vehicles.isEmpty {
                    await vm.fetchVehicles()
                }
            }
        }
    }
}

struct VehicleCardView: View {
    let vehicle: Vehicle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // 🔷 Image
            AsyncImage(url: URL(string: vehicle.imageURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.15)
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(12)
            
            // 🔷 Title + Subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.registrationNumber)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(
                    [vehicle.brand, vehicle.model]
                        .compactMap { $0 }
                        .joined(separator: " ")
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            // 🔷 Bottom Row
            HStack {
                NavigationLink {
                    VehicleDetailView(vehicleId: vehicle.id)
                } label: {
                    Text("Details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Image(systemName: "map.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
