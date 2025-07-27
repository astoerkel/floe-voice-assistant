//
//  SimpleUserProfileView.swift
//  VoiceAssistant
//
//  Created by Claude on 26.07.25.
//

import SwiftUI

struct SimpleUserProfileView: View {
    @StateObject private var userManager = SimpleUserManager.shared
    @State private var showingError = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        profileHeaderView
                        
                        // Account Information
                        accountInformationView
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .task {
            await userManager.fetchUserProfile()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(userManager.error ?? "Unknown error occurred")
        }
        .onChange(of: userManager.error) { _, newError in
            showingError = newError != nil
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeaderView: some View {
        VStack(spacing: 16) {
            // Profile Picture Placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.7))
                )
            
            VStack(spacing: 4) {
                Text(userManager.userProfile?.name ?? "Unknown User")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(userManager.userProfile?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - Account Information
    
    private var accountInformationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundColor(.blue)
                Text("Account Information")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if let profile = userManager.userProfile {
                VStack(spacing: 16) {
                    // Subscription Info
                    HStack {
                        Text("Subscription:")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        HStack {
                            Text(profile.subscriptionTier.capitalized)
                                .foregroundColor(.white)
                            statusBadge(for: profile.subscriptionStatus)
                        }
                    }
                    
                    // Usage Info
                    if profile.monthlyUsageLimit > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Monthly Usage:")
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text("\(profile.monthlyUsageCount)/\(profile.monthlyUsageLimit)")
                                    .foregroundColor(.white)
                            }
                            
                            ProgressView(value: Double(profile.monthlyUsageCount), total: Double(profile.monthlyUsageLimit))
                                .progressViewStyle(LinearProgressViewStyle(tint: profile.monthlyUsageCount >= profile.monthlyUsageLimit ? .red : .blue))
                        }
                    } else {
                        HStack {
                            Text("Monthly Usage:")
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text("Unlimited")
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Account Status
                    HStack {
                        Text("Account Status:")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        statusBadge(for: profile.isActive ? "Active" : "Inactive")
                    }
                }
            } else if userManager.isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Loading profile...")
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                Text("No profile data available")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    // MARK: - Helper Views
    
    private func statusBadge(for status: String) -> some View {
        Text(status)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor(for: status))
            )
            .foregroundColor(.white)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "active":
            return .green
        case "cancelled":
            return .orange
        case "expired", "inactive":
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    SimpleUserProfileView()
}