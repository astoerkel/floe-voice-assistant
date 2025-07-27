//
//  HomeDashboardView.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI

struct HomeDashboardView: View {
    @StateObject private var calendarVM = CalendarViewModel()
    @StateObject private var tasksVM = TasksViewModel()
    @StateObject private var emailVM = EmailViewModel()
    @State private var showingVoiceInterface = false
    @State private var showMenu = false
    @ObservedObject private var apiClient = APIClient.shared
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Dark background
                    Color.black.ignoresSafeArea()
                    
                    // Particle effect background
                    ParticleBackgroundView(
                        isVoiceActive: showingVoiceInterface,
                        isAudioPlaying: false
                    )
                    
                    ScrollView {
                        VStack(spacing: 30) {
                            // Header with menu
                            headerView
                            
                            // Enhanced Voice Button
                            VoiceButtonHero(showingInterface: $showingVoiceInterface)
                            
                            // At-a-Glance Cards
                            AtAGlanceCardsSection(
                                calendarEvents: calendarVM.upcomingEvents,
                                taskCount: tasksVM.todayTaskCount,
                                unreadEmails: emailVM.unreadCount
                            )
                            
                            // Quick Actions Row
                            QuickActionsRow()
                            
                            // Recent Commands
                            RecentCommandsSection()
                            
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showMenu) {
            MenuView(conversationHistory: .constant([]), apiClient: apiClient)
        }
        .sheet(isPresented: $showingVoiceInterface) {
            ContentView()
        }
        .onAppear {
            loadDashboardData()
        }
    }
    
    private var headerView: some View {
        HStack {
            // Hamburger Menu Button
            Button(action: { showMenu.toggle() }) {
                Image(systemName: "line.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Menu")
            .accessibilityHint("Opens the main menu")
            
            Spacer()
            
            // FLOE Title - Centered
            Text("Floe")
                .font(.custom("Corinthia", size: 48))
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
            
            // Profile/Settings
            Button(action: {
                // Handle profile action
            }) {
                Image(systemName: "person.circle")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Profile")
        }
        .padding(.top, 60)
    }
    
    private func loadDashboardData() {
        Task {
            await calendarVM.loadUpcomingEvents()
            await tasksVM.loadTodayTasks()
            await emailVM.loadUnreadCount()
        }
    }
}

struct VoiceButtonHero: View {
    @Binding var showingInterface: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                showingInterface = true
            }) {
                ZStack {
                    // Background glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(0.3),
                                    Color.purple.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                    
                    // Main button
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "mic.fill")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color.blue.opacity(0.5), radius: 20, x: 0, y: 10)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Voice Assistant")
            .accessibilityHint("Tap to start voice interaction")
            
            Text("Tap to speak with Floe")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.vertical, 20)
    }
}

// MARK: - ViewModels

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var upcomingEvents: [CalendarEvent] = []
    @Published var todayEvents: [CalendarEvent] = []
    @Published var isLoading = false
    
    func loadUpcomingEvents() async {
        isLoading = true
        
        do {
            let calendarService = CalendarService.shared
            upcomingEvents = try await calendarService.getUpcomingEvents(limit: 5)
        } catch {
            print("❌ Failed to load upcoming events: \(error)")
            // Fallback to mock data
            upcomingEvents = [
                CalendarEvent(
                    id: "1",
                    title: "Team Meeting",
                    startTime: Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date(),
                    endTime: Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date(),
                    location: "Conference Room A"
                ),
                CalendarEvent(
                    id: "2",
                    title: "Project Review",
                    startTime: Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date(),
                    endTime: Calendar.current.date(byAdding: .hour, value: 5, to: Date()) ?? Date(),
                    location: "Zoom"
                )
            ]
        }
        
        isLoading = false
    }
    
    func createEvent(from voiceCommand: VoiceCommand) async throws -> CalendarEvent {
        let calendarService = CalendarService.shared
        return try await calendarService.createEventFromVoiceCommand(voiceCommand.text)
    }
}

@MainActor
class TasksViewModel: ObservableObject {
    @Published var todayTaskCount = 0
    @Published var completedTaskCount = 0
    @Published var isLoading = false
    
    func loadTodayTasks() async {
        isLoading = true
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Mock data
        todayTaskCount = 5
        completedTaskCount = 2
        
        isLoading = false
    }
}

@MainActor
class EmailViewModel: ObservableObject {
    @Published var unreadCount = 0
    @Published var isLoading = false
    
    func loadUnreadCount() async {
        isLoading = true
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Mock data
        unreadCount = 12
        
        isLoading = false
    }
}

// MARK: - Models

// CalendarEvent is now defined in SharedModels.swift

struct VoiceCommand {
    let text: String
    let intent: String
    let timestamp: Date
}

// CalendarError is now defined in CalendarService.swift

#Preview {
    HomeDashboardView()
}