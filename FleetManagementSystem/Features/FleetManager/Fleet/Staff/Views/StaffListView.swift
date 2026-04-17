
//
//  StaffListView.swift
//  FleetManagementSystem
//
//  Staff tab — mirrors the same FAB (floating action button) 
//  styling used in FleetListView for consistency.
//

import SwiftUI

struct StaffListView: View {

    @State private var navigateToAddPerson = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {

                // ——— Content ———
                Text("Staff List")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray6))

                // ——— FAB — taps push AddPersonFlowView onto the stack ———
                Button {
                    navigateToAddPerson = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color(red: 59/255, green: 13/255, blue: 17/255))
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 30)
                .zIndex(1)
            }
            .navigationTitle("Staff")
            // ——— Hidden NavigationLink drives the push ———
            .navigationDestination(isPresented: $navigateToAddPerson) {
                AddPersonFlowView()
            }
        }
    }
}

#Preview {
    StaffListView()
}
