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
                .foregroundColor(Color(.systemGray))
            
            HStack {
                Text(value)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(Color(.systemGray))
            }
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
    }
}
