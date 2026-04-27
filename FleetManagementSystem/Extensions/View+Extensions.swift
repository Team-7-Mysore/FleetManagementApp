import SwiftUI

extension View {
    /// Dismisses the keyboard when the user taps anywhere on the view.
    /// This is useful for views with TextFields where you want to dismiss the keyboard by tapping outside.
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

extension UIApplication {
    /// Helper to dismiss the keyboard from anywhere in the app.
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
