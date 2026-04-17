import SwiftUI

struct FleetListView: View {
    
    var body: some View {
        
        NavigationStack {
            
            ZStack(alignment: .bottomTrailing) {
                
           
                Text("Fleet List")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))
                
               
                NavigationLink(destination: AddVehicleView()) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.TechBlue)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 30)
                .zIndex(1)
            }
            .navigationTitle("Fleet")
        }
    }
}
