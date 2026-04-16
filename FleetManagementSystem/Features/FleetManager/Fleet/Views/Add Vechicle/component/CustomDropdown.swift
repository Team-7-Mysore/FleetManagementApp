//
//  CustomDropdown.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 16/04/26.
//

import SwiftUI
struct CustomDropdown: View {
    
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            
            HStack {
                Text(value)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}
