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
    var isOptional: Bool = false
    var showDivider: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection = option
                    }
                }
            } label: {
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
                    
                    HStack(spacing: 4) {
                        Text(selection)
                            .foregroundColor(.TechBlue)
                            .font(.body)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            
            if showDivider {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}
