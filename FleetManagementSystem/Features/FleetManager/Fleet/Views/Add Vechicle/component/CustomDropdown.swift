//
//  CustomDropdown.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 16/04/26.
//

import SwiftUI
struct CustomDropdown: View {
    
    let title: String
    let options: [String]
    @Binding var selection: String
    
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text(title)
                .font(.caption2)
                .foregroundColor(Color(.systemGray))
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option  
                    }
                }
            } label: {
                HStack {
                    Text(selection)
                        .foregroundColor(.primary)
                        .font(.subheadline)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(Color(.systemGray))
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            }
        }
    }
}
