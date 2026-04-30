import SwiftUI

struct TopBarView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    let profile: UserProfile?
    let title: String
    let onProfileTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Spacer()

                HStack(spacing: 20) {
                    NavigationLink(destination: NotificationsView()) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex: "#A3352A"))

                            if notificationManager.unreadCount > 0 {
                                Text("\(notificationManager.unreadCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -2)
                            }
                        }
                    }

                    Button(action: onProfileTap) {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundColor(Color(hex: "#A3352A"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }

            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    NavigationStack {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack {
                TopBarView(profile: nil, title: "Inventory", onProfileTap: {})
                    .environmentObject(NotificationManager.shared)
                Spacer()
            }
        }
    }
}
