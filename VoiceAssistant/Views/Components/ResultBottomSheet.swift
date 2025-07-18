//
//  ResultBottomSheet.swift
//  VoiceAssistant
//
//  Created by Claude on 18.07.25.
//

import SwiftUI

struct ResultBottomSheet: View {
    let result: VoiceCommandResult
    @State private var detentHeight: PresentationDetent = .medium
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Result Summary
                    ResultSummaryCard(result: result)
                    
                    // Action Buttons
                    ResultActionButtons(result: result)
                    
                    // Detailed Information
                    if let details = result.details {
                        ResultDetailsView(details: details)
                    }
                    
                    // Follow-up Actions
                    FollowUpActionsView(resultType: result.type)
                }
                .padding()
            }
            .navigationTitle("Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detentHeight)
        .presentationDragIndicator(.visible)
    }
}

struct ResultSummaryCard: View {
    let result: VoiceCommandResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.type.icon)
                    .foregroundColor(result.type.color)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(result.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if result.isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ResultActionButtons: View {
    let result: VoiceCommandResult
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(result.actions, id: \.self) { action in
                    ActionButton(action: action, result: result)
                }
            }
        }
    }
}

struct ActionButton: View {
    let action: String
    let result: VoiceCommandResult
    
    var body: some View {
        Button(action: {
            performAction(action, for: result)
        }) {
            VStack(spacing: 8) {
                Image(systemName: iconForAction(action))
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(action)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconForAction(_ action: String) -> String {
        switch action.lowercased() {
        case "edit", "modify": return "pencil"
        case "delete", "remove": return "trash"
        case "share": return "square.and.arrow.up"
        case "copy": return "doc.on.doc"
        case "details", "view": return "info.circle"
        case "retry": return "arrow.clockwise"
        default: return "ellipsis"
        }
    }
    
    private func performAction(_ action: String, for result: VoiceCommandResult) {
        print("Performing action: \(action) for result: \(result.title)")
        // TODO: Implement actual action handling
    }
}

struct ResultDetailsView: View {
    let details: VoiceCommandDetails
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                if let created = details.created {
                    DetailRow(label: "Created", value: formatDate(created))
                }
                
                if let location = details.location {
                    DetailRow(label: "Location", value: location)
                }
                
                if let duration = details.duration {
                    DetailRow(label: "Duration", value: duration)
                }
                
                if let participants = details.participants, !participants.isEmpty {
                    DetailRow(label: "Participants", value: participants.joined(separator: ", "))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct FollowUpActionsView: View {
    let resultType: VoiceCommandType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Follow-up Actions")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(followUpActions, id: \.self) { action in
                    Button(action: {
                        performFollowUpAction(action)
                    }) {
                        HStack {
                            Image(systemName: iconForFollowUpAction(action))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text(action)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var followUpActions: [String] {
        switch resultType {
        case .calendar:
            return ["Add attendees", "Set reminder", "Change location", "Reschedule"]
        case .email:
            return ["Reply", "Forward", "Schedule follow-up", "Mark as read"]
        case .task:
            return ["Set due date", "Add subtasks", "Set priority", "Add details"]
        case .weather:
            return ["Check forecast", "Set weather alert", "View radar", "Check other locations"]
        default:
            return ["Ask follow-up", "Get more details", "Schedule reminder", "Share result"]
        }
    }
    
    private func iconForFollowUpAction(_ action: String) -> String {
        switch action.lowercased() {
        case "add attendees": return "person.badge.plus"
        case "set reminder": return "bell"
        case "change location": return "location"
        case "reschedule": return "calendar"
        case "reply": return "arrowshape.turn.up.left"
        case "forward": return "arrowshape.turn.up.right"
        case "schedule follow-up": return "calendar.badge.plus"
        case "mark as read": return "envelope.open"
        case "set due date": return "calendar"
        case "add subtasks": return "plus.circle"
        case "set priority": return "exclamationmark.circle"
        case "add details": return "text.badge.plus"
        default: return "ellipsis"
        }
    }
    
    private func performFollowUpAction(_ action: String) {
        print("Performing follow-up action: \(action)")
        // TODO: Implement actual follow-up action handling
    }
}

// MARK: - Supporting Models

struct VoiceCommandResult: Identifiable {
    let id = UUID()
    let title: String
    let summary: String
    let type: VoiceCommandType
    let isSuccess: Bool
    let details: VoiceCommandDetails?
    let actions: [String]
    let timestamp: Date
    
    init(title: String, summary: String, type: VoiceCommandType, isSuccess: Bool = true, details: VoiceCommandDetails? = nil, actions: [String] = [], timestamp: Date = Date()) {
        self.title = title
        self.summary = summary
        self.type = type
        self.isSuccess = isSuccess
        self.details = details
        self.actions = actions
        self.timestamp = timestamp
    }
}

struct VoiceCommandDetails {
    let created: Date?
    let location: String?
    let duration: String?
    let participants: [String]?
    let additionalInfo: [String: String]?
    
    init(created: Date? = nil, location: String? = nil, duration: String? = nil, participants: [String]? = nil, additionalInfo: [String: String]? = nil) {
        self.created = created
        self.location = location
        self.duration = duration
        self.participants = participants
        self.additionalInfo = additionalInfo
    }
}

enum VoiceCommandType {
    case calendar
    case email
    case task
    case weather
    case general
    
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .email: return "envelope"
        case .task: return "checkmark.circle"
        case .weather: return "cloud.sun"
        case .general: return "bubble.left"
        }
    }
    
    var color: Color {
        switch self {
        case .calendar: return .blue
        case .email: return .red
        case .task: return .green
        case .weather: return .orange
        case .general: return .gray
        }
    }
}

#Preview {
    ResultBottomSheet(
        result: VoiceCommandResult(
            title: "Meeting Scheduled",
            summary: "Successfully scheduled team meeting for tomorrow at 2:00 PM",
            type: .calendar,
            details: VoiceCommandDetails(
                created: Date(),
                location: "Conference Room A",
                duration: "1 hour",
                participants: ["John Doe", "Jane Smith", "Bob Johnson"]
            ),
            actions: ["Edit", "Share", "Delete", "Details"]
        )
    )
}