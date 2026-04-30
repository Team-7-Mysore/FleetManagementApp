import SwiftUI

struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isOptional: Bool = false
    var hint: String? = nil
    var showDivider: Bool = true
    
    @State private var showHintPopover = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
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
                
                if let hint = hint {
                    Button(action: { showHintPopover = true }) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.TechBlue)
                    }
                    .popover(isPresented: $showHintPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                        Text(hint)
                            .font(.body)
                            .padding()
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .padding(.top, 8)
            
            TextField(placeholder, text: $text)
                .font(.body)
                .padding(.bottom, 8)
            
            if showDivider {
                Divider()
                    .padding(.trailing, -16)
            }
        }
        .padding(.horizontal, 16)
    }
}
