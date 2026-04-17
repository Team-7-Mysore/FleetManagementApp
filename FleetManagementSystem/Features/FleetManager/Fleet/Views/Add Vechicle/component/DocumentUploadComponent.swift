import SwiftUI

struct DocumentUploadComponent: View {
    let title: String
    var isUploaded: Bool = false
    var fileName: String? = nil
    
    var body: some View {
        HStack {
            Text(title.capitalized)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isUploaded {
                Image(systemName: "doc.fill")
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 4) {
                    Text("Upload")
                    Image(systemName: "square.and.arrow.up")
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
