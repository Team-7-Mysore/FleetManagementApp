//
//  CustomTextField.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 16/04/26.
//

import SwiftUI
struct CustomTextField: View {
    
    let title: String
    let placeholder: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text(title)
                .font(.caption2)
                .foregroundColor(Color(.systemGray))
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
