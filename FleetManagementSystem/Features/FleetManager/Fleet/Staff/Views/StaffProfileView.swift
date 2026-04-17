//
//  StaffProfileView.swift
//  FleetManagementSystem
//
//  Profile detail screen for driver and maintenance staff users.
//  Used by Fleet Manager to monitor performance, track activity, and manage assignments.
//

import SwiftUI

struct StaffProfileView: View {
    let staff: StaffUser

    private var accentColor: Color {
        switch staff.role {
        case .driver:      return Color(red: 59/255,  green: 13/255,  blue: 17/255)
        case .maintenance: return Color(red: 30/255,  green: 80/255,  blue: 160/255)
        case .manager:     return Color(red: 40/255,  green: 120/255, blue: 70/255)
        }
    }

    private func roleGradient(_ role: UserRole) -> LinearGradient {
        switch role {
        case .driver:
            return LinearGradient(
                colors: [Color(red: 59/255, green: 13/255, blue: 17/255),
                         Color(red: 110/255, green: 40/255, blue: 48/255)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .maintenance:
            return LinearGradient(
                colors: [Color(red: 25/255, green: 70/255, blue: 150/255),
                         Color(red: 60/255, green: 120/255, blue: 195/255)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .manager:
            return LinearGradient(
                colors: [Color(red: 40/255, green: 120/255, blue: 70/255),
                         Color(red: 80/255, green: 160/255, blue: 110/255)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Header Section
                headerSection

                // 2. Performance Card (Dummy Data)
                performanceCard

                // 3. Contact Information
                contactSection
                
                // 4. Last Known Location (Dummy Data)
                locationSection

                // 5. Recent Activity (Dummy Data)
                activitySection
                
                // 6. Upcoming Assignments (Dummy Data)
                assignmentsSection
            }
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Staff Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(roleGradient(staff.role))
                        .frame(width: 90, height: 90)
                        .shadow(color: accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                    Text(staff.initials)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                
                // Online Indicator
                if staff.status == .active {
                    Circle()
                        .fill(Color(red: 0.1, green: 0.72, blue: 0.35))
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(Color(.systemGroupedBackground), lineWidth: 3))
                        .offset(x: -4, y: -4)
                }
            }
            
            VStack(spacing: 6) {
                Text(staff.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(staff.role.displayName) • ID: \(staff.user_id.prefix(8).uppercased())")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                if let status = staff.status {
                    Text(status.displayName.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor(status))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor(status).opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var performanceCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Safety Rating")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 16))
                    Text("4.9")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("/ 5.0")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
                .frame(height: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Distance Driven")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Text("142,800 mi")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 25/255, green: 70/255, blue: 150/255), Color(red: 60/255, green: 120/255, blue: 195/255)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.blue.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }

    private var contactSection: some View {
        InfoSectionCard(title: "Contact Information", icon: "person.text.rectangle") {
            ProfileInfoRow(icon: "envelope.fill", label: "Email", value: staff.email)
            Divider().padding(.leading, 46)
            if let phone = staff.phone_no, !phone.isEmpty {
                ProfileInfoRow(icon: "phone.fill", label: "Phone", value: phone)
                Divider().padding(.leading, 46)
            }
            ProfileInfoRow(icon: "mappin.and.ellipse", label: "Location", value: "Main Terminal")
        }
        .padding(.horizontal, 16)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("LAST KNOWN LOCATION")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(0.5)
            }
            .foregroundColor(Color.primaryBrown.opacity(0.8))
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                // Map placeholder
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 140)
                    
                    Image(systemName: "map.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.4))
                        
                    // Current position dot
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vehicle 204")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Updated 5 mins ago")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        // Action for track live
                    } label: {
                        Text("Track Live")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(16)
                .background(Color.white)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .padding(.horizontal, 16)
    }

    private var activitySection: some View {
        InfoSectionCard(title: "Recent Activity", icon: "list.bullet.rectangle.portrait") {
            ActivityRow(icon: "checkmark.circle.fill", iconColor: .green, title: "Completed Route", subtitle: "Route A-42 • 2 hours ago")
            Divider().padding(.leading, 46)
            ActivityRow(icon: "clock.fill", iconColor: .blue, title: "Clocked In", subtitle: "Main Terminal • 6:00 AM")
            Divider().padding(.leading, 46)
            ActivityRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, title: "Reported Maintenance", subtitle: "Tire pressure low • Yesterday")
        }
        .padding(.horizontal, 16)
    }

    private var assignmentsSection: some View {
        InfoSectionCard(title: "Upcoming Assignments", icon: "calendar") {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "box.truck.fill")
                        .foregroundColor(.purple)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Logistics Delivery")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("High Priority")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text("Tomorrow, 8:00 AM - 4:00 PM")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Route: Main Terminal → Warehouse B")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func statusColor(_ status: AccountStatus) -> Color {
        switch status {
        case .active:   return Color(red: 0.1, green: 0.72, blue: 0.35)
        case .pending:  return Color(red: 0.95, green: 0.55, blue: 0.1)
        case .inactive: return Color.gray
        }
    }
}

// MARK: - Info Section Card

private struct InfoSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .foregroundColor(Color.primaryBrown.opacity(0.8))
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            
            // Content
            VStack(spacing: 8) {
                content
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
    }
}

// MARK: - Profile Info Row

private struct ProfileInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.85))
                Text(subtitle)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
