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
    var isOptional: Bool = false
    var showDivider: Bool = true
    var range: ClosedRange<Date>? = nil
    var allowFutureOnly: Bool = false
    var allowPastOnly: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if isOptional {
                        Text("(optional)")
                            .font(.caption2)
                            .foregroundColor(Color(.placeholderText))
                    }
                }
                
                Spacer()
                
                if allowFutureOnly {
                    DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                } else if allowPastOnly {
                    DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                } else {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            
            if showDivider {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}
