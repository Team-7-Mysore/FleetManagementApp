import SwiftUI

struct TripsListView: View {
    var body: some View {
        NavigationView {
            Text("Trips")
                .navigationTitle("Trips")
        }
    }
}

#Preview {
    TripsListView()
}
