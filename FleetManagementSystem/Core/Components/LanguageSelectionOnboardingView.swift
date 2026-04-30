import SwiftUI

struct LanguageSelectionOnboardingView: View {
    @AppStorage("hasSelectedLanguage") private var hasSelectedLanguage: Bool = false
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"
    
    let languages = [
        ("en", "English"),
        ("hi", "हिंदी"),
        ("kn", "ಕನ್ನಡ"),
        ("mr", "मराठी")
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "globe")
                    .font(.system(size: 64))

                    .foregroundStyle(AppTheme.primaryGreen)

                
                Text("Select Language")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Choose your preferred language for the application. You can change this later in your profile.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 16) {
                ForEach(languages, id: \.0) { language in
                    Button {
                        selectedLanguage = language.0
                        // Short delay before dismissing to show the selection
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                hasSelectedLanguage = true
                            }
                        }
                    } label: {
                        HStack {
                            Text(language.1)
                                .font(.title3)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if selectedLanguage == language.0 {
                                Image(systemName: "checkmark.circle.fill")

                                    .foregroundStyle(AppTheme.primaryGreen)

                                    .font(.title3)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)

                                .stroke(selectedLanguage == language.0 ? AppTheme.primaryGreen : AppTheme.separator, lineWidth: 2)
                                .background(selectedLanguage == language.0 ? AppTheme.lightGreen.opacity(0.3) : Color.clear)

                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        )
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            

            Button("Continue") {
                withAnimation {
                    hasSelectedLanguage = true
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .disabled(selectedLanguage.isEmpty)

        }
        .environment(\.locale, .init(identifier: selectedLanguage))
    }
}

#Preview {
    LanguageSelectionOnboardingView()
}
