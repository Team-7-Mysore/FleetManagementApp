import SwiftUI

struct ChatView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Message from Dispatch")
                Text("Message from Driver 04")
                Text("System Notification")
            }
            .navigationTitle("Chat")
        }
    }
}

#Preview {
    ChatView()
}
