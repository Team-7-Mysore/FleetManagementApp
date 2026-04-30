import SwiftUI

struct LanguagePickerView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"
    
    let languages = [
        ("en", "English"),
        ("hi", "हिंदी"),
        ("kn", "ಕನ್ನಡ"),
        ("mr", "मराठी")
    ]
    
    var body: some View {
        Menu {
            ForEach(languages, id: \.0) { language in
                Button {
                    withAnimation {
                        selectedLanguage = language.0
                    }
                } label: {
                    HStack {
                        Text(language.1)
                        if selectedLanguage == language.0 {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "globe")
                Text(languages.first(where: { $0.0 == selectedLanguage })?.1 ?? "English")
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#Preview {
    LanguagePickerView()
}
