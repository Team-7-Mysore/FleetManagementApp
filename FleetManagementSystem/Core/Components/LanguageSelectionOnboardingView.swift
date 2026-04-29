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
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
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
                                    .foregroundStyle(.blue)
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(selectedLanguage == language.0 ? Color.blue : AppTheme.separator, lineWidth: 2)
                                .background(selectedLanguage == language.0 ? Color.blue.opacity(0.1) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                        )
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button {
                withAnimation {
                    hasSelectedLanguage = true
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Continue")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(height: 58)
                .shadow(color: .blue.opacity(0.22), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .disabled(selectedLanguage.isEmpty)
            .opacity(selectedLanguage.isEmpty ? 0.65 : 1)
        }
        .environment(\.locale, .init(identifier: selectedLanguage))
    }
}

#Preview {
    LanguageSelectionOnboardingView()
}
