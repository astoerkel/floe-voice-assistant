//
//  AtAGlanceCardsSection.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI

struct AtAGlanceCardsSection: View {
    let calendarEvents: [CalendarEvent]
    let taskCount: Int
    let unreadEmails: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("At a Glance")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                NextEventCard(event: calendarEvents.first)
                TaskCountCard(count: taskCount)
                EmailCountCard(count: unreadEmails)
                WeatherCard()
            }
        }
    }
}

struct NextEventCard: View {
    let event: CalendarEvent?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Spacer()
                
                if let event = event {
                    Text(timeUntilEvent(event.startTime))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Next Event")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                
                if let event = event {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(formatTime(event.startTime))
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("No upcoming events")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func timeUntilEvent(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "Now"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TaskCountCard: View {
    let count: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Tasks")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                
                Text("\(count)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("remaining")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EmailCountCard: View {
    let count: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "envelope")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Spacer()
                
                if count > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Unread")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                
                Text("\(count)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("emails")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct WeatherCard: View {
    @State private var weather: WeatherInfo?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: weather?.iconName ?? "sun.max")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Spacer()
                
                if let weather = weather {
                    Text(weather.condition)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Weather")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                
                if let weather = weather {
                    Text("\(weather.temperature)°")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(weather.location)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("Loading...")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            loadWeatherData()
        }
    }
    
    private func loadWeatherData() {
        // Simulate weather API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            weather = WeatherInfo(
                temperature: 72,
                condition: "Sunny",
                location: "New York",
                iconName: "sun.max"
            )
        }
    }
}

struct WeatherInfo {
    let temperature: Int
    let condition: String
    let location: String
    let iconName: String
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            AtAGlanceCardsSection(
                calendarEvents: [
                    CalendarEvent(
                        id: "1",
                        title: "Team Meeting",
                        startTime: Date().addingTimeInterval(3600),
                        endTime: Date().addingTimeInterval(7200),
                        location: "Conference Room A"
                    )
                ],
                taskCount: 5,
                unreadEmails: 12
            )
            
            Spacer()
        }
        .padding()
    }
}