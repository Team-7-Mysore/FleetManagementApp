import SwiftUI

struct CustomDropdown: View {
    let title: String
    let options: [String]
    @Binding var selection: String
    var showDivider: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Picker("", selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu) 
                .tint(.blue)
                .labelsHidden()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .background(Color.white)
            
            if showDivider {
                Divider().padding(.leading, 16)
            }
        }
    }
}
