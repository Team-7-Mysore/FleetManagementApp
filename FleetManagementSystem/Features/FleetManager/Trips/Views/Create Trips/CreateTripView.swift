import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = TripViewModel()

    @State private var tripName = ""
    @State private var clientContact = ""
    @State private var origin = ""
    @State private var destination = ""
    @State private var viaPointInput = ""
    @State private var viaPoints: [String] = []
    @State private var pickupDate = Date()

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Color(hex: "F5F6F8")
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // MARK: Title section
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 0) {
                                Text("Book ")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                Text("Your Next")
                                    .font(.system(size: 34, weight: .regular))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                            }
                            
                            Text("Breakthrough")
                                .font(.system(size: 34, weight: .regular))
                                .foregroundColor(Color(hex: "1A1A2E"))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        
                        // MARK: Trip Info block
                        VStack(spacing: 16) {
                            inputCard {
                                TextField("Trip Name (e.g. Weekly Restock)", text: $tripName)
                                    .font(.system(size: 15))
                            }
                            
                            inputCard {
                                TextField("Client Contact Info", text: $clientContact)
                                    .font(.system(size: 15))
                            }
                        }
                        .padding(.horizontal, 20)

                        // MARK: Origin & Destination Block
                        VStack(spacing: 0) {
                            HStack(alignment: .top, spacing: 16) {
                                // Route visualizer (dots + line)
                                VStack(spacing: 0) {
                                    Circle()
                                        .stroke(Color(hex: "00B87C"), lineWidth: 2)
                                        .frame(width: 14, height: 14)
                                        .overlay(Circle().fill(Color(hex: "00B87C")).frame(width: 6, height: 6))
                                    
                                    // Dashed line
                                    Path { path in
                                        path.move(to: CGPoint(x: 7, y: 0))
                                        path.addLine(to: CGPoint(x: 7, y: 30))
                                    }
                                    .stroke(Color(hex: "D1D5DB"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                    .frame(width: 14, height: 30)
                                    
                                    Circle()
                                        .stroke(Color.red, lineWidth: 2)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Image(systemName: "mappin")
                                                .font(.system(size: 8))
                                                .foregroundColor(.red)
                                        )
                                }
                                .padding(.top, 16)

                                // Text Fields
                                VStack(spacing: 16) {
                                    inputField(placeholder: "Enter Pickup Address", text: $origin)
                                    inputField(placeholder: "Enter Delivery Address", text: $destination)
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 20)
                            
                            // Bottom Action Row
                            HStack {
                                // Date Picker HIG style
                                DatePicker("", selection: $pickupDate)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                
                                Spacer()
                                
                                Button(action: {
                                    Task {
                                        await vm.createTrip(
                                            tripName: tripName,
                                            clientContact: clientContact,
                                            origin: origin,
                                            destination: destination,
                                            viaPoints: viaPoints,
                                            pickupDate: pickupDate
                                        )
                                        if vm.errorMessage == nil {
                                            dismiss()
                                        }
                                    }
                                }) {
                                    if vm.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .frame(width: 140, height: 48)
                                            .background(Color(hex: "6366F1"))
                                            .clipShape(Capsule())
                                    } else {
                                        Text("Booking Now")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 140, height: 48)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color(hex: "818CF8"), Color(hex: "6366F1")],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .clipShape(Capsule())
                                            .shadow(color: Color(hex: "6366F1").opacity(0.3), radius: 8, x: 0, y: 4)
                                    }
                                }
                                .disabled(vm.isLoading)
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 20)
                        
                        if !viaPoints.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Via Points")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                
                                ForEach(viaPoints, id: \.self) { point in
                                    Text("• \(point)")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "6B7280"))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        HStack {
                            TextField("Add Via Point", text: $viaPointInput)
                                .font(.system(size: 14))
                                .padding(14)
                                .background(Color.white)
                                .cornerRadius(12)
                            
                            Button(action: {
                                if !viaPointInput.isEmpty {
                                    withAnimation {
                                        viaPoints.append(viaPointInput)
                                        viaPointInput = ""
                                    }
                                }
                            }) {
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
                                    .padding(14)
                                    .background(Color(hex: "6366F1"))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if let error = vm.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 60) // Space for custom nav bar
                    .padding(.bottom, 40)
                }
                
                // Custom Navigation Bar Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "bell")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A2E"))
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Custom input stylings
    private func inputCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    private func inputField(placeholder: String, text: Binding<String>) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .font(.system(size: 14))
            Spacer()
        }
        .padding(16)
        .background(Color(hex: "F9FAFB"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "F3F4F6"), lineWidth: 1)
        )
    }
}
