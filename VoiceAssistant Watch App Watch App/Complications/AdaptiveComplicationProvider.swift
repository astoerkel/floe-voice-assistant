import Foundation
import WidgetKit
import SwiftUI

// NOTE: Complications require a separate Widget Extension target
// This is provided as a reference implementation for future widget extension setup
/*
struct AdaptiveComplicationProvider: TimelineProvider {
    typealias Entry = AdaptiveComplicationEntry
    
    func placeholder(in context: Context) -> AdaptiveComplicationEntry {
        AdaptiveComplicationEntry(
            date: Date(),
            contextType: .general,
            displayText: "Voice Assistant",
            detailText: "Tap to speak",
            urgencyLevel: .normal
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (AdaptiveComplicationEntry) -> Void) {
        let entry = createEntry(for: Date())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<AdaptiveComplicationEntry>) -> Void) {
        var entries: [AdaptiveComplicationEntry] = []
        let currentDate = Date()
        
        // Create entries for the next 4 hours (complications refresh every hour)
        for hourOffset in 0..<4 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = createEntry(for: entryDate)
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func createEntry(for date: Date) -> AdaptiveComplicationEntry {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let contextType = determineContextType(for: hour, date: date)
        
        return AdaptiveComplicationEntry(
            date: date,
            contextType: contextType,
            displayText: getDisplayText(for: contextType, hour: hour),
            detailText: getDetailText(for: contextType, hour: hour),
            urgencyLevel: getUrgencyLevel(for: contextType, hour: hour)
        )
    }
    
    private func determineContextType(for hour: Int, date: Date) -> ComplicationContextType {
        switch hour {
        case 6..<9:
            return .morning
        case 9..<12:
            return .workMorning
        case 12..<14:
            return .lunch
        case 14..<17:
            return .workAfternoon
        case 17..<20:
            return .evening
        case 20..<23:
            return .night
        default:
            return .general
        }
    }
    
    private func getDisplayText(for contextType: ComplicationContextType, hour: Int) -> String {
        switch contextType {
        case .morning:
            return "Morning"
        case .workMorning:
            return "Work"
        case .lunch:
            return "Lunch"
        case .workAfternoon:
            return "Work"
        case .evening:
            return "Evening"
        case .night:
            return "Night"
        case .general:
            return "Voice"
        }
    }
    
    private func getDetailText(for contextType: ComplicationContextType, hour: Int) -> String {
        switch contextType {
        case .morning:
            return "Next meeting"
        case .workMorning, .workAfternoon:
            return "\(getMockTaskCount()) tasks"
        case .lunch:
            return "Free time"
        case .evening:
            return "Tomorrow's first"
        case .night:
            return "Good night"
        case .general:
            return "Tap to speak"
        }
    }
    
    private func getUrgencyLevel(for contextType: ComplicationContextType, hour: Int) -> UrgencyLevel {
        switch contextType {
        case .morning:
            return .high
        case .workMorning, .workAfternoon:
            return .medium
        case .lunch:
            return .low
        case .evening:
            return .low
        case .night:
            return .low
        case .general:
            return .normal
        }
    }
    
    private func getMockTaskCount() -> Int {
        // In a real implementation, this would fetch from the phone or cached data
        return Int.random(in: 1...5)
    }
}

struct AdaptiveComplicationEntry: TimelineEntry {
    let date: Date
    let contextType: ComplicationContextType
    let displayText: String
    let detailText: String
    let urgencyLevel: UrgencyLevel
}

enum ComplicationContextType {
    case morning
    case workMorning
    case lunch
    case workAfternoon
    case evening
    case night
    case general
    
    var icon: String {
        switch self {
        case .morning:
            return "sun.rise"
        case .workMorning, .workAfternoon:
            return "briefcase"
        case .lunch:
            return "fork.knife"
        case .evening:
            return "sun.dust"
        case .night:
            return "moon"
        case .general:
            return "mic"
        }
    }
    
    var color: Color {
        switch self {
        case .morning:
            return .orange
        case .workMorning, .workAfternoon:
            return .blue
        case .lunch:
            return .green
        case .evening:
            return .purple
        case .night:
            return .indigo
        case .general:
            return .primary
        }
    }
}

enum UrgencyLevel {
    case low
    case normal
    case medium
    case high
    
    var opacity: Double {
        switch self {
        case .low:
            return 0.6
        case .normal:
            return 0.8
        case .medium:
            return 0.9
        case .high:
            return 1.0
        }
    }
}
*/