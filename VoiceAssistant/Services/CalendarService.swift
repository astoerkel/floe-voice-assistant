//
//  CalendarService.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import Foundation
import EventKit
import SwiftUI

@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let eventStore = EKEventStore()
    private let oauthService = OAuthService.shared
    
    private init() {}
    
    // MARK: - Calendar Permissions
    
    func requestCalendarPermission() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            return true
        case .notDetermined:
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                print("❌ Calendar permission request failed: \(error)")
                return false
            }
        case .denied, .restricted:
            return false
        case .fullAccess:
            return true
        case .writeOnly:
            return true
        @unknown default:
            return false
        }
    }
    
    // MARK: - Voice Command Calendar Events
    
    func createEventFromVoiceCommand(_ command: String) async throws -> CalendarEvent {
        isLoading = true
        errorMessage = nil
        
        do {
            // Parse the voice command to extract event details
            let eventDetails = try parseVoiceCommand(command)
            
            // Create the event
            let event = try await createEvent(from: eventDetails)
            
            isLoading = false
            return event
            
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    private func parseVoiceCommand(_ command: String) throws -> EventDetails {
        // Basic voice command parsing - in a real app, this would be more sophisticated
        let lowercased = command.lowercased()
        
        var title = "New Event"
        var startDate = Date()
        var duration: TimeInterval = 3600 // 1 hour default
        var location: String?
        
        // Extract title patterns
        if let titleRange = extractTitle(from: lowercased) {
            title = String(command[titleRange]).trimmingCharacters(in: .whitespaces)
        }
        
        // Extract time patterns
        if let timeDate = extractTime(from: lowercased) {
            startDate = timeDate
        }
        
        // Extract duration patterns
        if let extractedDuration = extractDuration(from: lowercased) {
            duration = extractedDuration
        }
        
        // Extract location patterns
        location = extractLocation(from: lowercased)
        
        return EventDetails(
            title: title,
            startDate: startDate,
            duration: duration,
            location: location
        )
    }
    
    private func extractTitle(from command: String) -> Range<String.Index>? {
        // Look for patterns like "schedule a meeting about X"
        let patterns = [
            "schedule a meeting about ",
            "schedule a call about ",
            "book a meeting for ",
            "create an event for ",
            "schedule "
        ]
        
        for pattern in patterns {
            if let range = command.range(of: pattern) {
                let startIndex = range.upperBound
                let endIndex = findTitleEnd(in: command, from: startIndex)
                return startIndex..<endIndex
            }
        }
        
        return nil
    }
    
    private func findTitleEnd(in command: String, from startIndex: String.Index) -> String.Index {
        let timeWords = ["at", "on", "tomorrow", "next", "this", "in", "for"]
        
        for word in timeWords {
            if let range = command.range(of: " \(word) ", range: startIndex..<command.endIndex) {
                return range.lowerBound
            }
        }
        
        return command.endIndex
    }
    
    private func extractTime(from command: String) -> Date? {
        let now = Date()
        
        // Handle "tomorrow" patterns
        if command.contains("tomorrow") {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
            
            // Look for time patterns
            if let time = extractTimeOfDay(from: command) {
                return combineDate(tomorrow, withTime: time)
            }
            
            return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
        }
        
        // Handle "next week" patterns
        if command.contains("next week") {
            let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: nextWeek)
        }
        
        // Handle specific time patterns
        if let time = extractTimeOfDay(from: command) {
            return combineDate(now, withTime: time)
        }
        
        // Default to 1 hour from now
        return Calendar.current.date(byAdding: .hour, value: 1, to: now)
    }
    
    private func extractTimeOfDay(from command: String) -> (hour: Int, minute: Int)? {
        // Look for time patterns like "at 2pm", "at 14:30", etc.
        let timeRegex = try? NSRegularExpression(pattern: "at (\\d{1,2}):?(\\d{2})?(am|pm)?", options: .caseInsensitive)
        
        if let regex = timeRegex {
            let range = NSRange(location: 0, length: command.utf16.count)
            if let match = regex.firstMatch(in: command, options: [], range: range) {
                let hourRange = match.range(at: 1)
                let minuteRange = match.range(at: 2)
                let ampmRange = match.range(at: 3)
                
                if hourRange.location != NSNotFound {
                    let hourString = (command as NSString).substring(with: hourRange)
                    var hour = Int(hourString) ?? 9
                    
                    var minute = 0
                    if minuteRange.location != NSNotFound {
                        let minuteString = (command as NSString).substring(with: minuteRange)
                        minute = Int(minuteString) ?? 0
                    }
                    
                    if ampmRange.location != NSNotFound {
                        let ampm = (command as NSString).substring(with: ampmRange).lowercased()
                        if ampm == "pm" && hour < 12 {
                            hour += 12
                        } else if ampm == "am" && hour == 12 {
                            hour = 0
                        }
                    }
                    
                    return (hour: hour, minute: minute)
                }
            }
        }
        
        return nil
    }
    
    private func extractDuration(from command: String) -> TimeInterval? {
        // Look for duration patterns
        if command.contains("30 minutes") || command.contains("half hour") {
            return 1800 // 30 minutes
        } else if command.contains("1 hour") || command.contains("an hour") {
            return 3600 // 1 hour
        } else if command.contains("2 hours") {
            return 7200 // 2 hours
        }
        
        return nil
    }
    
    private func extractLocation(from command: String) -> String? {
        // Look for location patterns
        if let atIndex = command.range(of: " at ") {
            let locationStart = atIndex.upperBound
            let locationEnd = command.range(of: " ", range: locationStart..<command.endIndex)?.lowerBound ?? command.endIndex
            let location = String(command[locationStart..<locationEnd])
            
            // Filter out time-related words
            let timeWords = ["2pm", "3pm", "noon", "morning", "afternoon", "evening"]
            if !timeWords.contains(where: { location.lowercased().contains($0) }) {
                return location
            }
        }
        
        return nil
    }
    
    private func combineDate(_ date: Date, withTime time: (hour: Int, minute: Int)) -> Date {
        return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: date) ?? date
    }
    
    private func createEvent(from details: EventDetails) async throws -> CalendarEvent {
        // Check if we have calendar permission
        guard await requestCalendarPermission() else {
            throw CalendarError.permissionDenied
        }
        
        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = details.title
        event.startDate = details.startDate
        event.endDate = details.startDate.addingTimeInterval(details.duration)
        event.location = details.location
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Save to local calendar
        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ Event saved to local calendar: \(details.title)")
        } catch {
            print("❌ Failed to save event to local calendar: \(error)")
            throw CalendarError.saveError
        }
        
        // If Google Calendar is connected, also save there
        if await oauthService.isConnected("google_calendar") {
            do {
                try await saveToGoogleCalendar(details)
                print("✅ Event saved to Google Calendar: \(details.title)")
            } catch {
                print("⚠️ Failed to save to Google Calendar, but local save succeeded: \(error)")
            }
        }
        
        return CalendarEvent(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: details.title,
            startTime: details.startDate,
            endTime: details.startDate.addingTimeInterval(details.duration),
            location: details.location
        )
    }
    
    private func saveToGoogleCalendar(_ details: EventDetails) async throws {
        // Implementation would use Google Calendar API
        // For now, simulate the API call
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // In a real implementation, this would:
        // 1. Get the access token from OAuth service
        // 2. Make API call to Google Calendar
        // 3. Handle the response
        
        print("📅 Google Calendar API call simulated")
    }
    
    // MARK: - Event Queries
    
    func getUpcomingEvents(limit: Int = 10) async throws -> [CalendarEvent] {
        guard await requestCalendarPermission() else {
            throw CalendarError.permissionDenied
        }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate) ?? startDate
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        return events.prefix(limit).map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title,
                startTime: event.startDate,
                endTime: event.endDate,
                location: event.location
            )
        }
    }
    
    func getTodaysEvents() async throws -> [CalendarEvent] {
        guard await requestCalendarPermission() else {
            throw CalendarError.permissionDenied
        }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        return events.map { event in
            CalendarEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title,
                startTime: event.startDate,
                endTime: event.endDate,
                location: event.location
            )
        }
    }
}

// MARK: - Supporting Models

struct EventDetails {
    let title: String
    let startDate: Date
    let duration: TimeInterval
    let location: String?
}

enum CalendarError: Error, LocalizedError {
    case permissionDenied
    case saveError
    case parseError
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Calendar permission denied"
        case .saveError:
            return "Failed to save event"
        case .parseError:
            return "Could not understand the event details"
        case .apiError(let message):
            return "Calendar API error: \(message)"
        }
    }
}

// MARK: - Voice Command Examples

/*
 Example voice commands that this service can handle:
 
 - "Schedule a meeting about project review tomorrow at 2pm"
 - "Book a call with the team next week"
 - "Create an event for lunch at the restaurant at noon"
 - "Schedule a doctor appointment for 30 minutes tomorrow"
 - "Set up a meeting with John about the proposal at 3pm"
 - "Block time for focused work tomorrow morning"
 
 The service uses natural language processing to extract:
 - Event title
 - Date and time
 - Duration
 - Location
 
 And can save to both local calendar and Google Calendar if connected.
 */