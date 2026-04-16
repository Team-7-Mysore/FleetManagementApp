import SwiftUI

struct DocumentUploadComponent: View {
    let title: String
    var isUploaded: Bool = false
    var fileName: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(Color(.systemGray))
            
            if isUploaded {
                // Uploaded State
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primaryBrown.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "doc.text")
                            .foregroundColor(.primaryBrown)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileName ?? "Document.pdf")
                            .font(.footnote)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("UPLOADED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Text("REPLACE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .foregroundColor(.primaryBrown)
                            .cornerRadius(6)
                            .shadow(color: .black.opacity(0.05), radius: 2)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
            } else {
                // Empty State
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 40, height: 40)
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        Image(systemName: "arrow.up.circle")
                            .foregroundColor(Color(.systemGray))
                    }
                    
                    Text("Tap to upload")
                        .font(.footnote)
                        .fontWeight(.bold)
                    
                    Text("JPG, PNG or PDF")
                        .font(.caption2)
                        .foregroundColor(Color(.systemGray).opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(Color(.systemGray5))
                .cornerRadius(12)
            }
        }
    }
}
