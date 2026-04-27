import SwiftUI

extension View {
    /// Dismisses the keyboard when the user scrolls or drags.
    /// Uses the native iOS `scrollDismissesKeyboard` API which does NOT
    /// intercept taps, buttons, or NavigationLinks in any way.
    func hideKeyboardOnTap() -> some View {
        self.scrollDismissesKeyboard(.immediately)
    }
}

extension UIApplication {
    /// Helper to dismiss the keyboard programmatically from anywhere.
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
