import Foundation
import NaturalLanguage

/// Manages response templates for different query types with natural language expressions
class ResponseTemplateManager {
    
    // MARK: - Template Storage
    private let templates: [ResponseType: [ResponseTemplate]]
    private let fallbackTemplates: [ResponseTemplate]
    
    // MARK: - Natural Language Processing
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .sentimentScore])
    
    // MARK: - Initialization
    init() {
        self.templates = ResponseTemplateManager.loadAllTemplates()
        self.fallbackTemplates = ResponseTemplateManager.loadFallbackTemplates()
    }
    
    // MARK: - Main Template Methods
    
    /// Gets the most appropriate template for the given parameters
    func getTemplate(
        for responseType: ResponseType,
        query: String,
        context: ConversationContext
    ) -> ResponseTemplate {
        
        let availableTemplates = templates[responseType] ?? fallbackTemplates
        
        // Score templates based on context and query
        let scoredTemplates = availableTemplates.map { template in
            (template: template, score: scoreTemplate(template, query: query, context: context))
        }
        
        // Return the highest scored template
        return scoredTemplates.max { $0.score < $1.score }?.template ?? availableTemplates.first!
    }
    
    /// Fills template variables with context-specific information
    func fillTemplate(
        _ template: ResponseTemplate,
        with variables: [String: String]
    ) -> String {
        var result = template.text
        
        // Replace all variables in the template
        for (key, value) in variables {
            let placeholder = "{\(key)}"
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        
        // Handle conditional sections
        result = processConditionalSections(result, variables: variables)
        
        // Handle pluralization
        result = processPluralization(result, variables: variables)
        
        // Clean up any remaining unfilled placeholders
        result = cleanupUnfilledPlaceholders(result)
        
        return result
    }
    
    // MARK: - Template Scoring
    
    private func scoreTemplate(
        _ template: ResponseTemplate,
        query: String,
        context: ConversationContext
    ) -> Double {
        var score = 0.0
        
        // Base score from template priority
        score += Double(template.priority) * 10
        
        // Keyword matching score
        score += scoreKeywordMatch(template, query: query)
        
        // Context appropriateness score
        score += scoreContextMatch(template, context: context)
        
        // Recency bonus (prefer recently used templates less)
        score -= scoreRecencyPenalty(template, context: context)
        
        // Length preference score
        score += scoreLengthPreference(template, context: context)
        
        return score
    }
    
    private func scoreKeywordMatch(_ template: ResponseTemplate, query: String) -> Double {
        guard !template.keywords.isEmpty else { return 0 }
        
        let queryLowercase = query.lowercased()
        let matchingKeywords = template.keywords.filter { queryLowercase.contains($0.lowercased()) }
        
        return Double(matchingKeywords.count) / Double(template.keywords.count) * 20
    }
    
    private func scoreContextMatch(_ template: ResponseTemplate, context: ConversationContext) -> Double {
        var score = 0.0
        
        // Time of day matching
        let timeOfDay = context.timeContext.timeOfDay
        if template.timeContext.contains(timeOfDay) {
            score += 15
        }
        
        // Conversation turn matching
        if context.conversationTurn <= 2 && template.isGreeting {
            score += 10
        }
        
        // Previous response type continuity
        if let lastResponseType = context.lastResponseType,
           template.followsResponseType.contains(lastResponseType) {
            score += 5
        }
        
        return score
    }
    
    private func scoreRecencyPenalty(_ template: ResponseTemplate, context: ConversationContext) -> Double {
        // Check if this template was used recently
        let recentResponses = context.recentMessages.suffix(3).map { $0.text }
        
        for recentResponse in recentResponses {
            if recentResponse.contains(template.text.prefix(20)) {
                return 10 // Penalty for recent use
            }
        }
        
        return 0
    }
    
    private func scoreLengthPreference(_ template: ResponseTemplate, context: ConversationContext) -> Double {
        guard let userPrefs = context.userPreferences else { return 0 }
        
        let templateLength = template.text.count
        
        switch userPrefs.responseLength {
        case .brief:
            return templateLength < 50 ? 8 : -5
        case .medium:
            return templateLength >= 50 && templateLength <= 150 ? 8 : -3
        case .detailed:
            return templateLength > 100 ? 8 : -3
        }
    }
    
    // MARK: - Template Processing
    
    private func processConditionalSections(_ text: String, variables: [String: String]) -> String {
        var result = text
        
        // Pattern: [if:variable]content[/if]
        let conditionalPattern = "\\[if:([^\\]]+)\\]([^\\[]*?)\\[/if\\]"
        let regex = try? NSRegularExpression(pattern: conditionalPattern, options: [])
        
        let nsString = result as NSString
        let matches = regex?.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        // Process matches in reverse order to maintain string indices
        for match in matches.reversed() {
            let fullRange = match.range
            let variableRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            
            let variable = nsString.substring(with: variableRange)
            let content = nsString.substring(with: contentRange)
            
            // Check if variable exists and is not empty
            if let value = variables[variable], !value.isEmpty {
                result = nsString.replacingCharacters(in: fullRange, with: content)
            } else {
                result = nsString.replacingCharacters(in: fullRange, with: "")
            }
        }
        
        return result
    }
    
    private func processPluralization(_ text: String, variables: [String: String]) -> String {
        var result = text
        
        // Pattern: {count|singular|plural}
        let pluralPattern = "\\{([^|]+)\\|([^|]+)\\|([^}]+)\\}"
        let regex = try? NSRegularExpression(pattern: pluralPattern, options: [])
        
        let nsString = result as NSString
        let matches = regex?.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        for match in matches.reversed() {
            let fullRange = match.range
            let countVarRange = match.range(at: 1)
            let singularRange = match.range(at: 2)
            let pluralRange = match.range(at: 3)
            
            let countVar = nsString.substring(with: countVarRange)
            let singular = nsString.substring(with: singularRange)
            let plural = nsString.substring(with: pluralRange)
            
            if let countString = variables[countVar],
               let count = Int(countString) {
                let replacement = count == 1 ? singular : plural
                result = nsString.replacingCharacters(in: fullRange, with: replacement)
            }
        }
        
        return result
    }
    
    private func cleanupUnfilledPlaceholders(_ text: String) -> String {
        // Remove any remaining {variable} placeholders
        let pattern = "\\{[^}]+\\}"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        return regex?.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(location: 0, length: text.count),
            withTemplate: ""
        ) ?? text
    }
    
    // MARK: - Static Template Loading
    
    private static func loadAllTemplates() -> [ResponseType: [ResponseTemplate]] {
        return [
            .calendar: loadCalendarTemplates(),
            .email: loadEmailTemplates(),
            .task: loadTaskTemplates(),
            .weather: loadWeatherTemplates(),
            .timeDate: loadTimeDateTemplates(),
            .confirmation: loadConfirmationTemplates(),
            .clarification: loadClarificationTemplates(),
            .error: loadErrorTemplates(),
            .greeting: loadGreetingTemplates(),
            .general: loadGeneralTemplates()
        ]
    }
    
    private static func loadCalendarTemplates() -> [ResponseTemplate] {
        return [
            // Next meeting templates
            ResponseTemplate(
                id: "calendar_next_meeting",
                text: "Your next meeting is {event_title} [if:event_time]at {event_time}[/if][if:event_location] in {event_location}[/if].",
                responseType: .calendar,
                priority: 10,
                keywords: ["next meeting", "upcoming meeting", "next appointment"],
                timeContext: [.morning, .afternoon, .evening],
                variables: ["event_title", "event_time", "event_location"]
            ),
            ResponseTemplate(
                id: "calendar_next_meeting_casual",
                text: "You've got {event_title} coming up[if:event_time] at {event_time}[/if].",
                responseType: .calendar,
                priority: 8,
                keywords: ["next meeting", "what's next"],
                timeContext: [.morning, .afternoon],
                variables: ["event_title", "event_time"],
                formalityLevel: 0.3
            ),
            
            // Today's schedule templates
            ResponseTemplate(
                id: "calendar_today_schedule",
                text: "You have {meeting_count|one meeting|{meeting_count} meetings} today[if:first_meeting]: starting with {first_meeting} at {first_time}[/if].",
                responseType: .calendar,
                priority: 9,
                keywords: ["today's schedule", "today's meetings", "what's today"],
                timeContext: [.morning, .afternoon],
                variables: ["meeting_count", "first_meeting", "first_time"]
            ),
            ResponseTemplate(
                id: "calendar_today_free",
                text: "Good news! Your calendar is clear for today. Perfect time to catch up on other work.",
                responseType: .calendar,
                priority: 7,
                keywords: ["today's schedule", "free today", "no meetings"],
                timeContext: [.morning, .afternoon]
            ),
            
            // Meeting creation confirmation
            ResponseTemplate(
                id: "calendar_meeting_created",
                text: "Perfect! I've scheduled {event_title} for {event_date} at {event_time}[if:attendees] and invited {attendees}[/if].",
                responseType: .calendar,
                priority: 8,
                keywords: ["schedule meeting", "create meeting", "book appointment"],
                variables: ["event_title", "event_date", "event_time", "attendees"]
            )
        ]
    }
    
    private static func loadEmailTemplates() -> [ResponseTemplate] {
        return [
            // Email count templates
            ResponseTemplate(
                id: "email_count_unread",
                text: "You have {email_count|one new email|{email_count} new emails}[if:important_count], including {important_count} marked as important[/if].",
                responseType: .email,
                priority: 10,
                keywords: ["new emails", "unread emails", "check email"],
                timeContext: [.morning, .afternoon, .evening],
                variables: ["email_count", "important_count"]
            ),
            ResponseTemplate(
                id: "email_no_new",
                text: "Your inbox is all caught up! No new emails since you last checked.",
                responseType: .email,
                priority: 8,
                keywords: ["new emails", "check email"],
                timeContext: [.morning, .afternoon, .evening]
            ),
            
            // Email summary templates
            ResponseTemplate(
                id: "email_summary_senders",
                text: "Your recent emails are from {top_senders}[if:subject_preview]. The latest is about {subject_preview}[/if].",
                responseType: .email,
                priority: 9,
                keywords: ["email summary", "recent emails", "who emailed"],
                variables: ["top_senders", "subject_preview"]
            ),
            
            // Email sent confirmation
            ResponseTemplate(
                id: "email_sent_confirmation",
                text: "Your email to {recipient} has been sent successfully[if:subject] regarding {subject}[/if].",
                responseType: .email,
                priority: 8,
                keywords: ["send email", "email sent"],
                variables: ["recipient", "subject"]
            ),
            ResponseTemplate(
                id: "email_sent_casual",
                text: "Email sent to {recipient}! They should receive it shortly.",
                responseType: .email,
                priority: 7,
                keywords: ["send email", "sent"],
                variables: ["recipient"],
                formalityLevel: 0.3
            )
        ]
    }
    
    private static func loadTaskTemplates() -> [ResponseTemplate] {
        return [
            // Task creation templates
            ResponseTemplate(
                id: "task_created",
                text: "I've added \"{task_title}\" to your task list[if:due_date] with a due date of {due_date}[/if].",
                responseType: .task,
                priority: 10,
                keywords: ["add task", "create task", "remind me"],
                variables: ["task_title", "due_date"]
            ),
            ResponseTemplate(
                id: "task_created_casual",
                text: "Got it! \"{task_title}\" is now on your list[if:due_date] for {due_date}[/if].",
                responseType: .task,
                priority: 8,
                keywords: ["add task", "remember"],
                variables: ["task_title", "due_date"],
                formalityLevel: 0.3
            ),
            
            // Task completion templates
            ResponseTemplate(
                id: "task_completed",
                text: "Excellent! I've marked \"{task_title}\" as completed. {remaining_tasks|You have one task remaining|You have {remaining_tasks} tasks remaining|All caught up!}.",
                responseType: .task,
                priority: 9,
                keywords: ["task done", "complete task", "finished"],
                variables: ["task_title", "remaining_tasks"]
            ),
            
            // Task list templates
            ResponseTemplate(
                id: "task_list_summary",
                text: "You have {task_count|one task|{task_count} tasks} on your list[if:urgent_count], with {urgent_count} marked as urgent[/if][if:next_task]. Your next task is \"{next_task}\"[/if].",
                responseType: .task,
                priority: 9,
                keywords: ["my tasks", "task list", "what tasks"],
                variables: ["task_count", "urgent_count", "next_task"]
            )
        ]
    }
    
    private static func loadWeatherTemplates() -> [ResponseTemplate] {
        return [
            // Current weather templates
            ResponseTemplate(
                id: "weather_current",
                text: "It's currently {temperature} and {condition}[if:location] in {location}[/if][if:feels_like]. It feels like {feels_like}[/if].",
                responseType: .weather,
                priority: 10,
                keywords: ["current weather", "weather now", "temperature"],
                variables: ["temperature", "condition", "location", "feels_like"]
            ),
            ResponseTemplate(
                id: "weather_current_detailed",
                text: "The weather right now is {temperature} with {condition}[if:humidity]. Humidity is at {humidity}[/if][if:wind_speed] and winds are {wind_speed}[/if].",
                responseType: .weather,
                priority: 8,
                keywords: ["detailed weather", "weather conditions"],
                variables: ["temperature", "condition", "humidity", "wind_speed"]
            ),
            
            // Weather forecast templates
            ResponseTemplate(
                id: "weather_today_forecast",
                text: "Today's forecast shows {high_temp} high and {low_temp} low with {condition}[if:rain_chance]. There's a {rain_chance} chance of rain[/if].",
                responseType: .weather,
                priority: 9,
                keywords: ["today's weather", "weather forecast", "weather today"],
                timeContext: [.morning, .afternoon],
                variables: ["high_temp", "low_temp", "condition", "rain_chance"]
            )
        ]
    }
    
    private static func loadTimeDateTemplates() -> [ResponseTemplate] {
        return [
            // Current time templates
            ResponseTemplate(
                id: "time_current",
                text: "It's currently {time}[if:timezone] {timezone}[/if].",
                responseType: .timeDate,
                priority: 10,
                keywords: ["what time", "current time", "time now"],
                variables: ["time", "timezone"]
            ),
            ResponseTemplate(
                id: "time_current_casual",
                text: "It's {time} right now.",
                responseType: .timeDate,
                priority: 8,
                keywords: ["what time", "time"],
                variables: ["time"],
                formalityLevel: 0.3
            ),
            
            // Current date templates
            ResponseTemplate(
                id: "date_current",
                text: "Today is {weekday}, {date}.",
                responseType: .timeDate,
                priority: 10,
                keywords: ["what date", "today's date", "current date"],
                variables: ["weekday", "date"]
            ),
            
            // Time until event
            ResponseTemplate(
                id: "time_until_event",
                text: "There {time_value|is {time_value}|are {time_value}} until {event}.",
                responseType: .timeDate,
                priority: 8,
                keywords: ["time until", "how long until"],
                variables: ["time_value", "event"]
            )
        ]
    }
    
    private static func loadConfirmationTemplates() -> [ResponseTemplate] {
        return [
            ResponseTemplate(
                id: "confirmation_general",
                text: "Done! I've completed that for you.",
                responseType: .confirmation,
                priority: 8,
                keywords: ["confirmation", "done", "completed"]
            ),
            ResponseTemplate(
                id: "confirmation_enthusiastic",
                text: "Perfect! That's all taken care of.",
                responseType: .confirmation,
                priority: 7,
                keywords: ["confirmation", "success"]
            ),
            ResponseTemplate(
                id: "confirmation_detailed",
                text: "I've successfully completed your request[if:action] to {action}[/if]. Is there anything else you need?",
                responseType: .confirmation,
                priority: 9,
                keywords: ["confirmation", "completed"],
                variables: ["action"]
            )
        ]
    }
    
    private static func loadClarificationTemplates() -> [ResponseTemplate] {
        return [
            ResponseTemplate(
                id: "clarification_general",
                text: "I want to make sure I understand correctly. Could you provide a bit more detail about what you need?",
                responseType: .clarification,
                priority: 8,
                keywords: ["clarification", "unclear"]
            ),
            ResponseTemplate(
                id: "clarification_specific",
                text: "I'm not quite sure about {unclear_part}. Could you clarify that for me?",
                responseType: .clarification,
                priority: 9,
                keywords: ["clarification", "unclear"],
                variables: ["unclear_part"]
            )
        ]
    }
    
    private static func loadErrorTemplates() -> [ResponseTemplate] {
        return [
            ResponseTemplate(
                id: "error_general",
                text: "I apologize, but I encountered an issue completing your request. Please try again.",
                responseType: .error,
                priority: 8,
                keywords: ["error", "failed"]
            ),
            ResponseTemplate(
                id: "error_network",
                text: "I'm having trouble connecting right now. Please check your internet connection and try again.",
                responseType: .error,
                priority: 9,
                keywords: ["network error", "connection"]
            ),
            ResponseTemplate(
                id: "error_service",
                text: "The {service} service is temporarily unavailable. I'll try again in a moment.",
                responseType: .error,
                priority: 9,
                keywords: ["service error", "unavailable"],
                variables: ["service"]
            )
        ]
    }
    
    private static func loadGreetingTemplates() -> [ResponseTemplate] {
        return [
            ResponseTemplate(
                id: "greeting_morning",
                text: "Good morning! How can I help you today?",
                responseType: .greeting,
                priority: 10,
                keywords: ["hello", "hi", "good morning"],
                timeContext: [.morning],
                isGreeting: true
            ),
            ResponseTemplate(
                id: "greeting_afternoon",
                text: "Good afternoon! What can I do for you?",
                responseType: .greeting,
                priority: 10,
                keywords: ["hello", "hi", "good afternoon"],
                timeContext: [.afternoon],
                isGreeting: true
            ),
            ResponseTemplate(
                id: "greeting_evening",
                text: "Good evening! How may I assist you?",
                responseType: .greeting,
                priority: 10,
                keywords: ["hello", "hi", "good evening"],
                timeContext: [.evening, .night],
                isGreeting: true
            ),
            ResponseTemplate(
                id: "greeting_casual",
                text: "Hey there! What's up?",
                responseType: .greeting,
                priority: 7,
                keywords: ["hey", "hi"],
                formalityLevel: 0.2,
                isGreeting: true
            )
        ]
    }
    
    private static func loadGeneralTemplates() -> [ResponseTemplate] {
        return [
            ResponseTemplate(
                id: "general_help",
                text: "I can help you with calendar events, emails, tasks, weather, and general information. What would you like to know?",
                responseType: .general,
                priority: 8,
                keywords: ["help", "what can you do"]
            ),
            ResponseTemplate(
                id: "general_thanks",
                text: "You're welcome! I'm here whenever you need assistance.",
                responseType: .general,
                priority: 8,
                keywords: ["thank you", "thanks"]
            )
        ]
    }
    
    private static func loadFallbackTemplates() -> [ResponseTemplate] {
        return [
            ResponseTemplate(
                id: "fallback_general",
                text: "I understand you're asking about {topic}, but I need a bit more information to provide a helpful response.",
                responseType: .general,
                priority: 5,
                keywords: [],
                variables: ["topic"]
            ),
            ResponseTemplate(
                id: "fallback_simple",
                text: "I'm here to help! Could you please rephrase your question?",
                responseType: .general,
                priority: 3,
                keywords: []
            )
        ]
    }
}

// MARK: - Supporting Types

struct ResponseTemplate {
    let id: String
    let text: String
    let responseType: ResponseType
    let priority: Int
    let keywords: [String]
    let timeContext: [TimeOfDay]
    let variables: [String]
    let formalityLevel: Double
    let isGreeting: Bool
    let followsResponseType: [String]
    
    init(
        id: String,
        text: String,
        responseType: ResponseType,
        priority: Int,
        keywords: [String] = [],
        timeContext: [TimeOfDay] = [.morning, .afternoon, .evening, .night],
        variables: [String] = [],
        formalityLevel: Double = 0.5,
        isGreeting: Bool = false,
        followsResponseType: [String] = []
    ) {
        self.id = id
        self.text = text
        self.responseType = responseType
        self.priority = priority
        self.keywords = keywords
        self.timeContext = timeContext
        self.variables = variables
        self.formalityLevel = formalityLevel
        self.isGreeting = isGreeting
        self.followsResponseType = followsResponseType
    }
}