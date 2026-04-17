//
//  CustomDateField.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 16/04/26.
//

import SwiftUI
struct CustomDateField: View {
    
    let title: String
    @Binding var date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text(title)
                .font(.caption)
                .foregroundColor(Color(.systemGray))
            
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
    }
}
