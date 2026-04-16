import SwiftUI

struct FleetListView: View {
    var body: some View {
        ZStack {
            // Placeholder for the main list
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        // TODO: Add action
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 4)
                    }
                    .padding()
                }
            }
        }
    }
}

#Preview {
    FleetListView()
}
