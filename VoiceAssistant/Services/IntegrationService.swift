import Foundation

@MainActor
class IntegrationService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    private let oauthManager = OAuthManager()
    
    // MARK: - Calendar Integration
    
    func getCalendarEvents(from startDate: Date? = nil, to endDate: Date? = nil) async throws -> [CalendarEvent] {
        isLoading = true
        defer { isLoading = false }
        
        var queryParams: [String: String] = [:]
        
        if let startDate = startDate {
            queryParams["timeMin"] = ISO8601DateFormatter().string(from: startDate)
        }
        
        if let endDate = endDate {
            queryParams["timeMax"] = ISO8601DateFormatter().string(from: endDate)
        }
        
        queryParams["maxResults"] = "25"
        
        do {
            let response = try await apiClient.get("/api/integrations/calendar/events", queryParams: queryParams)
            
            if let eventsData = response["events"] as? [[String: Any]] {
                return try eventsData.compactMap { eventData in
                    let jsonData = try JSONSerialization.data(withJSONObject: eventData)
                    return try JSONDecoder().decode(CalendarEvent.self, from: jsonData)
                }
            }
            
            return []
        } catch {
            errorMessage = "Failed to fetch calendar events: \(error.localizedDescription)"
            throw error
        }
    }
    
    func createCalendarEvent(title: String, startDate: Date, endDate: Date, description: String? = nil) async throws -> CalendarEvent {
        isLoading = true
        defer { isLoading = false }
        
        let eventData: [String: Any] = [
            "summary": title,
            "start": ISO8601DateFormatter().string(from: startDate),
            "end": ISO8601DateFormatter().string(from: endDate),
            "description": description ?? ""
        ]
        
        do {
            let response = try await apiClient.post("/api/integrations/calendar/events", body: eventData)
            
            if let eventData = response["event"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: eventData)
                return try JSONDecoder().decode(CalendarEvent.self, from: jsonData)
            }
            
            throw IntegrationError.invalidResponse
        } catch {
            errorMessage = "Failed to create calendar event: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Email Integration
    
    func getEmails(query: String? = nil, maxResults: Int = 10) async throws -> [Email] {
        isLoading = true
        defer { isLoading = false }
        
        var queryParams: [String: String] = [
            "maxResults": "\(maxResults)"
        ]
        
        if let query = query {
            queryParams["q"] = query
        }
        
        do {
            let response = try await apiClient.get("/api/integrations/email/messages", queryParams: queryParams)
            
            if let emailsData = response["emails"] as? [[String: Any]] {
                return try emailsData.compactMap { emailData in
                    let jsonData = try JSONSerialization.data(withJSONObject: emailData)
                    return try JSONDecoder().decode(Email.self, from: jsonData)
                }
            }
            
            return []
        } catch {
            errorMessage = "Failed to fetch emails: \(error.localizedDescription)"
            throw error
        }
    }
    
    func sendEmail(to: String, subject: String, body: String, isHTML: Bool = false) async throws -> String {
        isLoading = true
        defer { isLoading = false }
        
        let emailData: [String: Any] = [
            "to": to,
            "subject": subject,
            "body": body,
            "html": isHTML ? body : nil
        ].compactMapValues { $0 }
        
        do {
            let response = try await apiClient.post("/api/integrations/email/send", body: emailData)
            
            if let messageId = response["messageId"] as? String {
                return messageId
            }
            
            throw IntegrationError.invalidResponse
        } catch {
            errorMessage = "Failed to send email: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Task Integration
    
    func getTasks(status: String? = nil, priority: String? = nil) async throws -> [Task] {
        isLoading = true
        defer { isLoading = false }
        
        var queryParams: [String: String] = [:]
        
        if let status = status {
            queryParams["status"] = status
        }
        
        if let priority = priority {
            queryParams["priority"] = priority
        }
        
        do {
            let response = try await apiClient.get("/api/integrations/tasks", queryParams: queryParams)
            
            if let tasksData = response["tasks"] as? [[String: Any]] {
                return try tasksData.compactMap { taskData in
                    let jsonData = try JSONSerialization.data(withJSONObject: taskData)
                    return try JSONDecoder().decode(Task.self, from: jsonData)
                }
            }
            
            return []
        } catch {
            errorMessage = "Failed to fetch tasks: \(error.localizedDescription)"
            throw error
        }
    }
    
    func createTask(title: String, description: String? = nil, priority: String = "Normal", dueDate: Date? = nil) async throws -> Task {
        isLoading = true
        defer { isLoading = false }
        
        var taskData: [String: Any] = [
            "title": title,
            "priority": priority
        ]
        
        if let description = description {
            taskData["description"] = description
        }
        
        if let dueDate = dueDate {
            taskData["dueDate"] = ISO8601DateFormatter().string(from: dueDate)
        }
        
        do {
            let response = try await apiClient.post("/api/integrations/tasks", body: taskData)
            
            if let taskData = response["task"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: taskData)
                return try JSONDecoder().decode(Task.self, from: jsonData)
            }
            
            throw IntegrationError.invalidResponse
        } catch {
            errorMessage = "Failed to create task: \(error.localizedDescription)"
            throw error
        }
    }
    
    func updateTask(_ taskId: String, title: String? = nil, description: String? = nil, status: String? = nil, priority: String? = nil) async throws -> Task {
        isLoading = true
        defer { isLoading = false }
        
        var taskData: [String: Any] = [:]
        
        if let title = title {
            taskData["title"] = title
        }
        
        if let description = description {
            taskData["description"] = description
        }
        
        if let status = status {
            taskData["status"] = status
        }
        
        if let priority = priority {
            taskData["priority"] = priority
        }
        
        do {
            let response = try await apiClient.put("/api/integrations/tasks/\(taskId)", body: taskData)
            
            if let taskData = response["task"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: taskData)
                return try JSONDecoder().decode(Task.self, from: jsonData)
            }
            
            throw IntegrationError.invalidResponse
        } catch {
            errorMessage = "Failed to update task: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Integration Status
    
    func checkIntegrationStatus(for service: String) async throws -> IntegrationStatus {
        do {
            let response = try await apiClient.get("/api/integrations/\(service)/status")
            
            if let integrationData = response["integration"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: integrationData)
                return try JSONDecoder().decode(IntegrationStatus.self, from: jsonData)
            }
            
            throw IntegrationError.invalidResponse
        } catch {
            errorMessage = "Failed to check integration status: \(error.localizedDescription)"
            throw error
        }
    }
}

// MARK: - Data Models

// CalendarEvent is now defined in SharedModels.swift

struct Email: Identifiable, Codable {
    let id: String
    let subject: String
    let from: String
    let to: [String]
    let body: String
    let isRead: Bool
    let isImportant: Bool
    let receivedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, subject, from, to, body, isRead, isImportant, receivedAt
    }
}

struct Task: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let status: String
    let priority: String
    let dueDate: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, status, priority, dueDate, createdAt, updatedAt
    }
}

struct IntegrationStatus: Codable {
    let id: String
    let type: String
    let isActive: Bool
    let lastSyncAt: Date?
    let createdAt: Date
    let expiresAt: Date?
    let syncErrors: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case id, type, isActive, lastSyncAt, createdAt, expiresAt, syncErrors
    }
}

// MARK: - Errors

enum IntegrationError: LocalizedError {
    case invalidResponse
    case serviceUnavailable
    case authenticationRequired
    case rateLimitExceeded
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from service"
        case .serviceUnavailable:
            return "Service is currently unavailable"
        case .authenticationRequired:
            return "Authentication required. Please reconnect your account."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .networkError:
            return "Network error. Please check your connection."
        }
    }
}