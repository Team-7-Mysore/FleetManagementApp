
import Combine
import SwiftUI
struct DocumentUploadComponent<Action: View>: View {
    let title: String
    var isUploaded: Bool = false
    var fileName: String? = nil
    let action: Action // The menu or button view
    
    init(title: String, isUploaded: Bool = false, fileName: String? = nil, @ViewBuilder action: () -> Action) {
        self.title = title
        self.isUploaded = isUploaded
        self.fileName = fileName
        self.action = action()
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if let fileName = fileName, !fileName.isEmpty {
                    Text(fileName.components(separatedBy: "/").last ?? fileName)
                        .font(.caption)
                        .foregroundColor(Color(.secondaryLabel))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
       
            action
        }
        .padding(.vertical, 8)
    }
}
