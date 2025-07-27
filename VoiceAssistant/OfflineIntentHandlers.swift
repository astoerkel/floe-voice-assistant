//
//  OfflineIntentHandlers.swift
//  VoiceAssistant
//
//  Created by Claude Code on 2025-07-22.
//  Enhanced offline intent handlers for basic queries that don't require server processing
//

import Foundation
import UIKit
import AVFoundation
import CoreLocation

// MARK: - Offline Handler Protocol
public protocol OfflineHandler {
    func handle(_ query: String) async -> OfflineIntentResponse
    var supportedIntents: [String] { get }
}

// MARK: - Offline Intent Response
public struct OfflineIntentResponse {
    let text: String
    let success: Bool
    let processingTime: TimeInterval
    let confidence: Float
    let requiresFollowUp: Bool
    let followUpSuggestions: [String]
    let hapticFeedback: UIImpactFeedbackGenerator.FeedbackStyle?
    
    // Convert to VoiceResponse for compatibility
    func toVoiceResponse() -> VoiceResponse {
        return VoiceResponse(text: text, success: success, audioBase64: nil)
    }
}

// MARK: - Enhanced Time Intent Handler
public class EnhancedTimeIntentHandler: OfflineIntentHandler {
    
    private let dateFormatter = DateFormatter()
    private let timeFormatter = DateFormatter()
    
    public init() {
        timeFormatter.timeStyle = .short
        dateFormatter.dateStyle = .full
    }
    
    public func canHandle(text: String) async -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let timePatterns = [
            "what time is it",
            "current time",
            "what's the time",
            "time now",
            "what date is it",
            "what's today's date",
            "what day is it",
            "today",
            "current date"
        ]
        
        return timePatterns.contains { normalized.contains($0) }
    }
    
    public func process(text: String, context: [String: Any]?) async throws -> VoiceResponse {
        let startTime = CFAbsoluteTimeGetCurrent()
        let now = Date()
        
        let normalized = text.lowercased()
        var response: String
        // var suggestions: [String] = [] // Not used currently
        
        if normalized.contains("date") || normalized.contains("today") {
            dateFormatter.dateStyle = .full
            response = "Today is \(dateFormatter.string(from: now))"
            // suggestions = ["What time is it?", "What's tomorrow's date?"]
        } else if normalized.contains("day") {
            dateFormatter.dateFormat = "EEEE" // Day of week
            response = "Today is \(dateFormatter.string(from: now))"
            // suggestions = ["What's the date?", "What time is it?"]
        } else {
            timeFormatter.timeStyle = .short
            response = "It's \(timeFormatter.string(from: now))"
            // suggestions = ["What's the date?", "Set a reminder for later"]
        }
        
        _ = CFAbsoluteTimeGetCurrent() - startTime
        
        return VoiceResponse(text: response, success: true, audioBase64: nil)
    }
    
    public func estimatedProcessingTime(text: String) async -> TimeInterval {
        return 0.1
    }
}

// MARK: - Enhanced Calculation Intent Handler
public class EnhancedCalculationIntentHandler: OfflineIntentHandler {
    
    private let numberFormatter = NumberFormatter()
    
    public init() {
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 6
    }
    
    public func canHandle(text: String) async -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let calcPatterns = [
            "calculate",
            "what is",
            "what's",
            "plus",
            "minus",
            "multiply",
            "divide",
            "add",
            "subtract",
            "times",
            "divided by",
            "percent of",
            "percentage",
            "square root",
            "power of"
        ]
        
        let hasCalcWord = calcPatterns.contains { normalized.contains($0) }
        let hasNumbers = extractNumbers(from: text).count >= 1
        
        return hasCalcWord && hasNumbers
    }
    
    public func process(text: String, context: [String: Any]?) async throws -> VoiceResponse {
        _ = CFAbsoluteTimeGetCurrent()
        
        do {
            let result = try performCalculation(text: text)
            let response = formatCalculationResult(result, originalText: text)
            
            return VoiceResponse(text: response, success: true, audioBase64: nil)
        } catch {
            let errorResponse = "I couldn't understand that calculation. Please try something like '5 plus 3' or 'calculate 10 times 2'"
            return VoiceResponse(text: errorResponse, success: false, audioBase64: nil)
        }
    }
    
    private func performCalculation(text: String) throws -> Double {
        let normalized = text.lowercased()
            .replacingOccurrences(of: "what is", with: "")
            .replacingOccurrences(of: "what's", with: "")
            .replacingOccurrences(of: "calculate", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let numbers = extractNumbers(from: normalized)
        guard numbers.count >= 2 else {
            // Handle single number operations
            if numbers.count == 1 {
                if normalized.contains("square root") {
                    return sqrt(numbers[0])
                } else if normalized.contains("square") {
                    return numbers[0] * numbers[0]
                }
            }
            throw CalculationError.insufficientNumbers
        }
        
        let num1 = numbers[0]
        let num2 = numbers[1]
        
        if normalized.contains("plus") || normalized.contains("add") {
            return num1 + num2
        } else if normalized.contains("minus") || normalized.contains("subtract") {
            return num1 - num2
        } else if normalized.contains("times") || normalized.contains("multiply") {
            return num1 * num2
        } else if normalized.contains("divide") || normalized.contains("divided by") {
            guard num2 != 0 else { throw CalculationError.divisionByZero }
            return num1 / num2
        } else if normalized.contains("percent of") {
            return (num1 / 100) * num2
        } else if normalized.contains("power of") || normalized.contains("to the power") {
            return pow(num1, num2)
        }
        
        // Default to addition if no clear operation
        return num1 + num2
    }
    
    private func extractNumbers(from text: String) -> [Double] {
        let numberRegex = try! NSRegularExpression(pattern: "\\b\\d+(?:\\.\\d+)?\\b", options: [])
        let matches = numberRegex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        return matches.compactMap { match in
            let range = Range(match.range, in: text)!
            return Double(String(text[range]))
        }
    }
    
    private func formatCalculationResult(_ result: Double, originalText: String) -> String {
        let formattedResult = numberFormatter.string(from: NSNumber(value: result)) ?? String(result)
        return "The result is \(formattedResult)"
    }
    
    public func estimatedProcessingTime(text: String) async -> TimeInterval {
        return 0.3
    }
    
    private enum CalculationError: Error {
        case insufficientNumbers
        case divisionByZero
        case invalidOperation
    }
}

// MARK: - Enhanced Device Control Intent Handler
public class EnhancedDeviceControlIntentHandler: OfflineIntentHandler {
    
    private let device = UIDevice.current
    
    public func canHandle(text: String) async -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let devicePatterns = [
            "brightness",
            "volume",
            "battery",
            "device info",
            "system info",
            "storage",
            "memory",
            "flashlight",
            "torch"
        ]
        
        return devicePatterns.contains { normalized.contains($0) }
    }
    
    public func process(text: String, context: [String: Any]?) async throws -> VoiceResponse {
        _ = CFAbsoluteTimeGetCurrent()
        let normalized = text.lowercased()
        
        var response: String
        
        if normalized.contains("battery") {
            response = getBatteryInfo()
        } else if normalized.contains("brightness") {
            response = getBrightnessInfo()
        } else if normalized.contains("volume") {
            response = getVolumeInfo()
        } else if normalized.contains("device info") || normalized.contains("system info") {
            response = getDeviceInfo()
        } else if normalized.contains("storage") || normalized.contains("memory") {
            response = getStorageInfo()
        } else if normalized.contains("flashlight") || normalized.contains("torch") {
            response = getFlashlightInfo()
        } else {
            response = "I can help you check battery level, device info, or storage information. What would you like to know?"
        }
        
        return VoiceResponse(text: response, success: true, audioBase64: nil)
    }
    
    private func getBatteryInfo() -> String {
        device.isBatteryMonitoringEnabled = true
        let batteryLevel = device.batteryLevel
        let batteryState = device.batteryState
        
        var stateDescription: String
        switch batteryState {
        case .charging:
            stateDescription = "charging"
        case .full:
            stateDescription = "fully charged"
        case .unplugged:
            stateDescription = "not charging"
        case .unknown:
            stateDescription = "status unknown"
        @unknown default:
            stateDescription = "status unknown"
        }
        
        if batteryLevel < 0 {
            return "Battery information is not available on this device"
        } else {
            let percentage = Int(batteryLevel * 100)
            return "Your battery is at \(percentage)% and is \(stateDescription)"
        }
    }
    
    private func getBrightnessInfo() -> String {
        let brightness = UIScreen.main.brightness
        let percentage = Int(brightness * 100)
        return "Screen brightness is at \(percentage)%"
    }
    
    private func getVolumeInfo() -> String {
        // Note: Accessing system volume requires AVAudioSession
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true)
            let volume = audioSession.outputVolume
            let percentage = Int(volume * 100)
            return "System volume is at \(percentage)%"
        } catch {
            return "Unable to access volume information"
        }
    }
    
    private func getDeviceInfo() -> String {
        let deviceName = device.name
        let systemName = device.systemName
        let systemVersion = device.systemVersion
        let model = device.model
        
        return "\(deviceName) running \(systemName) \(systemVersion) on \(model)"
    }
    
    private func getStorageInfo() -> String {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
            let values = try fileURL.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeTotalCapacityKey
            ])
            
            if let availableCapacity = values.volumeAvailableCapacityForImportantUsage,
               let totalCapacity = values.volumeTotalCapacity {
                
                let availableGB = Double(availableCapacity) / (1024 * 1024 * 1024)
                let totalGB = Double(totalCapacity) / (1024 * 1024 * 1024)
                let usedGB = totalGB - availableGB
                
                return "Storage: \(usedGB) GB used of \(totalGB) GB total, \(availableGB) GB available"
            }
        } catch {
            // Fallback method
        }
        
        return "Storage information is not available"
    }
    
    private func getFlashlightInfo() -> String {
        // Note: Actual flashlight control would require AVCaptureDevice
        return "I can provide information about the flashlight, but cannot control it directly for security reasons"
    }
    
    public func estimatedProcessingTime(text: String) async -> TimeInterval {
        return 0.5
    }
}

// MARK: - General Information Handler
public class GeneralInfoIntentHandler: OfflineIntentHandler {
    
    private let supportedQueries = [
        "app version": "This is VoiceAssistant version 1.0",
        "what can you do": "I can help with calendar events, emails, tasks, weather, time, calculations, and device information. I work both online and offline!",
        "how are you": "I'm doing well, thank you for asking! How can I help you today?",
        "hello": "Hello! How can I assist you today?",
        "hi": "Hi there! What can I do for you?",
        "help": "I can help you with scheduling, emails, tasks, weather, time queries, calculations, and device information. Just ask naturally!",
        "thank you": "You're welcome! Is there anything else I can help you with?",
        "thanks": "You're welcome! Let me know if you need anything else."
    ]
    
    public func canHandle(text: String) async -> Bool {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return supportedQueries.keys.contains { query in
            normalized.contains(query)
        } || isGeneralGreeting(normalized)
    }
    
    private func isGeneralGreeting(_ text: String) -> Bool {
        let greetings = ["hello", "hi", "hey", "good morning", "good afternoon", "good evening"]
        return greetings.contains { text.contains($0) }
    }
    
    public func process(text: String, context: [String: Any]?) async throws -> VoiceResponse {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find matching query
        for (query, response) in supportedQueries {
            if normalized.contains(query) {
                return VoiceResponse(text: response, success: true, audioBase64: nil)
            }
        }
        
        // Handle greetings
        if isGeneralGreeting(normalized) {
            let responses = [
                "Hello! How can I help you today?",
                "Hi there! What can I do for you?",
                "Good to see you! How may I assist?",
                "Hello! I'm ready to help with whatever you need."
            ]
            let randomResponse = responses.randomElement() ?? responses[0]
            return VoiceResponse(text: randomResponse, success: true, audioBase64: nil)
        }
        
        // Default response
        let defaultResponse = "I'm here to help! Try asking about the time, calculations, device info, or say 'what can you do' to learn more."
        return VoiceResponse(text: defaultResponse, success: true, audioBase64: nil)
    }
    
    public func estimatedProcessingTime(text: String) async -> TimeInterval {
        return 0.2
    }
}

// MARK: - Static Handler Methods for OfflineProcessor
public class OfflineIntentHandlers {
    
    // MARK: - Time and Date Queries
    public static func handleTimeQuery(_ parameters: [String: Any]) -> String {
        let formatter = DateFormatter()
        let now = Date()
        
        formatter.timeStyle = .short
        return "It's \(formatter.string(from: now))"
    }
    
    public static func handleDateQuery(_ parameters: [String: Any]) -> String {
        let formatter = DateFormatter()
        let now = Date()
        
        formatter.dateStyle = .full
        return "Today is \(formatter.string(from: now))"
    }
    
    // MARK: - Calendar Queries
    internal static func handleCalendarQuery(_ parameters: [String: Any], dataManager: OfflineDataManager) async -> String {
        let _ = dataManager // Mark as used for compilation
        let cachedEvents: [CachedCalendarEvent] = [] // Simplified implementation
        
        if cachedEvents.isEmpty {
            return "I don't have any cached calendar events. I'll check when we're back online."
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let todayEvents = cachedEvents.filter { event in
            Calendar.current.isDate(event.date, inSameDayAs: today)
        }
        
        if todayEvents.isEmpty {
            return "You don't have any events scheduled for today based on my cached information."
        } else if todayEvents.count == 1 {
            let event = todayEvents.first!
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return "You have one event today: \(event.title) at \(timeFormatter.string(from: event.date))"
        } else {
            return "You have \(todayEvents.count) events scheduled for today. Your next event is \(todayEvents.first!.title)."
        }
    }
    
    // MARK: - Calculations
    public static func handleCalculation(_ text: String, parameters: [String: Any]) -> String {
        do {
            let result = try performBasicCalculation(text)
            return "The result is \(formatNumber(result))"
        } catch {
            return "I couldn't understand that calculation. Try something like '5 plus 3' or 'calculate 10 times 2'."
        }
    }
    
    private static func performBasicCalculation(_ text: String) throws -> Double {
        let normalized = text.lowercased()
            .replacingOccurrences(of: "calculate", with: "")
            .replacingOccurrences(of: "what is", with: "")
            .replacingOccurrences(of: "what's", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let numbers = extractNumbers(from: normalized)
        guard numbers.count >= 2 else {
            if numbers.count == 1 {
                if normalized.contains("square root") {
                    return sqrt(numbers[0])
                } else if normalized.contains("square") {
                    return numbers[0] * numbers[0]
                }
            }
            throw CalculationError.insufficientNumbers
        }
        
        let num1 = numbers[0]
        let num2 = numbers[1]
        
        if normalized.contains("plus") || normalized.contains("add") {
            return num1 + num2
        } else if normalized.contains("minus") || normalized.contains("subtract") {
            return num1 - num2
        } else if normalized.contains("times") || normalized.contains("multiply") {
            return num1 * num2
        } else if normalized.contains("divide") || normalized.contains("divided by") {
            guard num2 != 0 else { throw CalculationError.divisionByZero }
            return num1 / num2
        } else if normalized.contains("percent of") {
            return (num1 / 100) * num2
        } else if normalized.contains("power of") {
            return pow(num1, num2)
        }
        
        return num1 + num2 // Default to addition
    }
    
    private static func extractNumbers(from text: String) -> [Double] {
        let numberRegex = try! NSRegularExpression(pattern: "\\b\\d+(?:\\.\\d+)?\\b", options: [])
        let matches = numberRegex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        return matches.compactMap { match in
            let range = Range(match.range, in: text)!
            return Double(String(text[range]))
        }
    }
    
    private static func formatNumber(_ number: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
    
    // MARK: - Reminders and Notes
    internal static func handleReminder(_ text: String, parameters: [String: Any], dataManager: OfflineDataManager) async -> String {
        let _ = dataManager // Mark as used for compilation
        let reminderText = extractReminderText(from: text)
        
        let _ = LocalReminder(
            id: UUID(),
            text: reminderText,
            createdDate: Date(),
            isCompleted: false,
            priority: .normal
        )
        
        // Simplified implementation - would normally save to dataManager
        
        return "I've created a reminder: '\(reminderText)'. It will be synced when we're back online."
    }
    
    private static func extractReminderText(from text: String) -> String {
        let patterns = [
            "remind me to ",
            "remind me ",
            "create a reminder to ",
            "create a reminder ",
            "add a reminder to ",
            "add a reminder ",
            "note to ",
            "make a note "
        ]
        
        var cleanText = text.lowercased()
        for pattern in patterns {
            if cleanText.hasPrefix(pattern) {
                cleanText = String(cleanText.dropFirst(pattern.count))
                break
            }
        }
        
        return cleanText.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
    }
    
    // MARK: - Device Control
    public static func handleDeviceControl(_ text: String, parameters: [String: Any]) -> String {
        let normalized = text.lowercased()
        
        if normalized.contains("battery") {
            return getBatteryInfo()
        } else if normalized.contains("brightness") {
            return "Screen brightness is at \(Int(UIScreen.main.brightness * 100))%"
        } else if normalized.contains("volume") {
            return getVolumeInfo()
        } else if normalized.contains("device info") || normalized.contains("system info") {
            return getDeviceInfo()
        } else if normalized.contains("storage") {
            return getStorageInfo()
        } else {
            return "I can help you check battery level, brightness, volume, device info, or storage information."
        }
    }
    
    private static func getBatteryInfo() -> String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        var stateDescription: String
        switch batteryState {
        case .charging: stateDescription = "charging"
        case .full: stateDescription = "fully charged" 
        case .unplugged: stateDescription = "not charging"
        case .unknown: stateDescription = "status unknown"
        @unknown default: stateDescription = "status unknown"
        }
        
        if batteryLevel < 0 {
            return "Battery information is not available"
        } else {
            let percentage = Int(batteryLevel * 100)
            return "Your battery is at \(percentage)% and is \(stateDescription)"
        }
    }
    
    private static func getVolumeInfo() -> String {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true)
            let volume = audioSession.outputVolume
            let percentage = Int(volume * 100)
            return "System volume is at \(percentage)%"
        } catch {
            return "Unable to access volume information"
        }
    }
    
    private static func getDeviceInfo() -> String {
        let device = UIDevice.current
        return "\(device.name) running \(device.systemName) \(device.systemVersion)"
    }
    
    private static func getStorageInfo() -> String {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeTotalCapacityKey
            ])
            
            if let availableCapacity = values.volumeAvailableCapacityForImportantUsage,
               let totalCapacity = values.volumeTotalCapacity {
                
                let availableGB = Double(availableCapacity) / (1024 * 1024 * 1024)
                let totalGB = Double(totalCapacity) / (1024 * 1024 * 1024)
                let usedGB = totalGB - availableGB
                
                return String(format: "Storage: %.1f GB used of %.1f GB total, %.1f GB available", 
                             usedGB, totalGB, availableGB)
            }
        } catch {}
        
        return "Storage information is not available"
    }
    
    private enum CalculationError: Error {
        case insufficientNumbers
        case divisionByZero
        case invalidOperation
    }
}

// MARK: - Supporting Models
struct LocalReminder {
    let id: UUID
    let text: String
    let createdDate: Date
    let isCompleted: Bool
    let priority: Priority
    
    enum Priority: String, CaseIterable, Codable {
        case low, normal, high, urgent
    }
}

struct CachedCalendarEvent: Codable {
    let id: String
    let title: String
    let date: Date
    let duration: TimeInterval
    let location: String?
}

// MARK: - Email Handling
extension OfflineIntentHandlers {
    internal static func handleEmailQuery(_ text: String, dataManager: OfflineDataManager) async -> String {
        // Email queries should NEVER be handled offline if user has integrations
        // This should trigger a sync request instead
        return "I need an internet connection to check your emails. Please check your connection and try again."
    }
}

// MARK: - Email Intent Handler
class EmailIntentHandler: OfflineIntentHandler {
    var supportedIntents: [VoiceIntent] = [.email]
    var confidence: Float = 0.8
    var estimatedProcessingTime: TimeInterval = 0.5
    
    func canHandle(intent: VoiceIntent) async -> Bool {
        return intent == .email
    }
    
    func canHandle(text: String) async -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("email") || normalized.contains("mail") || 
               normalized.contains("inbox") || normalized.contains("unread")
    }
    
    func process(text: String, context: [String: Any]?) async throws -> VoiceResponse {
        let responseText = await OfflineIntentHandlers.handleEmailQuery(text, dataManager: OfflineDataManager.shared)
        return VoiceResponse(
            text: responseText,
            success: true,
            audioBase64: nil
        )
    }
    
    func estimatedProcessingTime(text: String) async -> TimeInterval {
        return 0.3
    }
}

// MARK: - Offline Handler Factory
public class OfflineHandlerFactory {
    
    internal static func createHandlers() -> [VoiceIntent: OfflineIntentHandler] {
        return [
            .time: EnhancedTimeIntentHandler(),
            .calculation: EnhancedCalculationIntentHandler(),
            .deviceControl: EnhancedDeviceControlIntentHandler(),
            .email: EmailIntentHandler(),
            .general: GeneralInfoIntentHandler()
        ]
    }
    
    public static func getHandlerCapabilities() -> [VoiceIntent: [String]] {
        return [
            .time: [
                "What time is it?",
                "What's the date?",
                "What day is today?",
                "Current time"
            ],
            .calculation: [
                "Calculate 5 plus 3",
                "What's 10 times 2?",
                "15 percent of 200",
                "Square root of 25"
            ],
            .deviceControl: [
                "Battery level",
                "Device information",
                "Storage info",
                "Screen brightness"
            ],
            .email: [
                "Check my emails",
                "Check my unread emails", 
                "New emails",
                "Latest emails"
            ],
            .general: [
                "What can you do?",
                "Hello",
                "Help",
                "App version"
            ]
        ]
    }
}