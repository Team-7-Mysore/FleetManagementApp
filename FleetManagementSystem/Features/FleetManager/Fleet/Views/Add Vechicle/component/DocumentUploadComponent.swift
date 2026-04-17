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
                HStack(spacing: 4) {
                    Text("Replace")
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .foregroundColor(.blue)
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
