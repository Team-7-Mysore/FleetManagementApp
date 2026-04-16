import SwiftUI

struct TripsListView: View {
    @State private var showCreateTrip = false

    var body: some View {
        NavigationView {
            ZStack {
                Text("Trips")

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showCreateTrip = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Trips")
            .sheet(isPresented: $showCreateTrip) {
                CreateTripView()
            }
        }
    }
}

#Preview {
    TripsListView()
}
