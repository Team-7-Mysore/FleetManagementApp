//
//  CustomDateField.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 16/04/26.
//

import SwiftUI
struct CustomDateField: View {
    
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
            
            HStack {
                Text("dd/mm/yyyy")
                    .foregroundColor(.gray)
                
                Spacer()
                
                Image(systemName: "calendar")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}
