import SwiftUI

/// Personalization and ML model settings view
struct PersonalizationSettingsView: View {
    @StateObject private var personalizationEngine = PersonalizationEngine()
    @StateObject private var performanceOptimizer = MLPerformanceOptimizer()
    @StateObject private var quantization: ModelQuantization
    @StateObject private var intentClassifier: IntentClassifier
    @State private var showingClearLearningAlert = false
    @State private var showingPersonalizationDetails = false
    
    init() {
        let optimizer = MLPerformanceOptimizer()
        let quantizationManager = ModelQuantization(performanceOptimizer: optimizer)
        self._quantization = StateObject(wrappedValue: quantizationManager)
        self._intentClassifier = StateObject(wrappedValue: IntentClassifier())
    }
    
    var body: some View {
        List {
            // Personalization Status
            Section {
                PersonalizationStatusView(personalizationEngine: personalizationEngine)
            } header: {
                Text("Learning Status")
            }
            
            // User Preferences
            Section {
                UserPreferencesView(personalizationEngine: personalizationEngine)
            } header: {
                Text("Communication Preferences")
            } footer: {
                Text("These preferences help customize responses to match your style.")
            }
            
            // Intent Classification
            Section {
                IntentClassificationView(intentClassifier: intentClassifier)
            } header: {
                Text("Intent Classification")
            } footer: {
                Text("ML models analyze your requests to provide more accurate responses.")
            }
            
            // ML Model Performance
            Section {
                MLModelPerformanceView(
                    performanceOptimizer: performanceOptimizer,
                    quantization: quantization
                )
            } header: {
                Text("Model Performance")
            }
            
            // Learning Statistics
            Section {
                LearningStatisticsView(personalizationEngine: personalizationEngine)
            } header: {
                Text("Learning Statistics")
            }
            
            // Privacy & Data Management
            Section {
                PrivacyControlsView(personalizationEngine: personalizationEngine)
            } header: {
                Text("Privacy & Data")
            } footer: {
                Text("All learning happens on-device. Your data never leaves your device.")
            }
            
            // Data Management
            Section {
                Button("Clear Learning Data") {
                    showingClearLearningAlert = true
                }
                .foregroundColor(.red)
                
                Button("Export Learning Statistics") {
                    exportLearningData()
                }
                
                HStack {
                    Text("Learning Interactions")
                    Spacer()
                    Text("\(personalizationEngine.learningStatistics.totalInteractions)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Data Management")
            }
        }
        .navigationTitle("ML & Personalization")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear Learning Data", isPresented: $showingClearLearningAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                // Clear learning data - this would call a method to reset learning statistics
                // For now, we'll just reset the UI state
                personalizationEngine.learningStatistics = LearningStats()
            }
        } message: {
            Text("This will clear all personalization data and reset learning preferences. This action cannot be undone.")
        }
        .sheet(isPresented: $showingPersonalizationDetails) {
            PersonalizationDetailsView(personalizationEngine: personalizationEngine)
        }
    }
    
    private func exportLearningData() {
        // Export learning statistics (privacy-preserving)
        let stats = personalizationEngine.learningStatistics
        // In a real implementation, would share via system share sheet
        print("Learning statistics exported: Total interactions: \(stats.totalInteractions), Feedback received: \(stats.feedbackReceived), Adaptations made: \(stats.adaptationsMade)")
    }
}

// MARK: - Supporting Views

struct PersonalizationStatusView: View {
    @ObservedObject var personalizationEngine: PersonalizationEngine
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StatusIndicator(
                    title: "Learning Status",
                    value: personalizationEngine.isLearning ? "Active" : "Idle",
                    color: personalizationEngine.isLearning ? .green : .gray,
                    icon: personalizationEngine.isLearning ? "brain.head.profile" : "brain.head.profile.fill"
                )
                
                Spacer()
                
                StatusIndicator(
                    title: "Interactions",
                    value: "\(personalizationEngine.learningStatistics.totalInteractions)",
                    color: .blue,
                    icon: "chart.bar"
                )
            }
            
            HStack {
                StatusIndicator(
                    title: "Feedback Rate",
                    value: String(format: "%.1f%%", personalizationEngine.learningStatistics.feedbackRate * 100),
                    color: .purple,
                    icon: "target"
                )
                
                Spacer()
                
                StatusIndicator(
                    title: "Adaptations",
                    value: "\(personalizationEngine.learningStatistics.adaptationsMade)",
                    color: .orange,
                    icon: "speedometer"
                )
            }
        }
    }
}

struct UserPreferencesView: View {
    @ObservedObject var personalizationEngine: PersonalizationEngine
    
    var body: some View {
        VStack(spacing: 16) {
            PreferenceSlider(
                title: "Response Length",
                value: .constant(0.5),
                range: 0...1,
                formatter: { value in
                    ["Brief", "Balanced", "Detailed"][Int(value * 2)]
                }
            )
            
            PreferenceSlider(
                title: "Formality Level",
                value: .constant(0.3),
                range: 0...1,
                formatter: { value in
                    ["Casual", "Friendly", "Professional"][Int(value * 2)]
                }
            )
            
            PreferenceSlider(
                title: "Technical Detail",
                value: .constant(0.7),
                range: 0...1,
                formatter: { value in
                    ["Simple", "Moderate", "Technical"][Int(value * 2)]
                }
            )
        }
    }
}

struct PreferenceSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let formatter: (Double) -> String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(formatter(value))
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range)
                .tint(.blue)
        }
    }
}

struct IntentClassificationView: View {
    @ObservedObject var intentClassifier: IntentClassifier
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Classification Accuracy")
                        .font(.subheadline)
                    Text(String(format: "%.1f%%", intentClassifier.statistics.averageConfidence * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Processing Time")
                        .font(.subheadline)
                    Text(String(format: "%.0fms", intentClassifier.statistics.averageProcessingTime * 1000))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            Toggle("Enable On-Device Classification", isOn: .constant(true))
            Toggle("Enable Entity Extraction", isOn: .constant(true))
        }
    }
}

struct MLModelPerformanceView: View {
    @ObservedObject var performanceOptimizer: MLPerformanceOptimizer
    @ObservedObject var quantization: ModelQuantization
    
    var body: some View {
        VStack(spacing: 12) {
            Picker("Performance Mode", selection: .constant(PerformanceMode.balanced)) {
                ForEach(PerformanceMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thermal State")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(performanceOptimizer.thermalState.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(thermalStateColor(performanceOptimizer.thermalState))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Battery Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", performanceOptimizer.batteryLevel * 100))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(batteryColor(performanceOptimizer.batteryLevel))
                }
            }
        }
    }
    
    private func thermalStateColor(_ state: ThermalState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
    
    private func batteryColor(_ level: Float) -> Color {
        if level > 0.5 { return .green }
        if level > 0.2 { return .orange }
        return .red
    }
}

struct LearningStatisticsView: View {
    @ObservedObject var personalizationEngine: PersonalizationEngine
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StatisticView(
                    title: "Feedback Received",
                    value: "\(personalizationEngine.learningStatistics.feedbackReceived)",
                    color: .green
                )
                
                Spacer()
                
                StatisticView(
                    title: "Total Interactions",
                    value: "\(personalizationEngine.learningStatistics.totalInteractions)",
                    color: .blue
                )
            }
            
            HStack {
                StatisticView(
                    title: "Feedback Rate",
                    value: String(format: "%.1f%%", personalizationEngine.learningStatistics.feedbackRate * 100),
                    color: .purple
                )
                
                Spacer()
                
                StatisticView(
                    title: "Adaptations Made",
                    value: "\(personalizationEngine.learningStatistics.adaptationsMade)",
                    color: .orange
                )
            }
        }
    }
}

struct StatisticView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct PrivacyControlsView: View {
    @ObservedObject var personalizationEngine: PersonalizationEngine
    
    var body: some View {
        VStack(spacing: 12) {
            Toggle("Enable Learning", isOn: .constant(true))
            Toggle("Share Anonymous Analytics", isOn: .constant(false))
            
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("On-Device Processing")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("All learning happens locally on your device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
}

struct PersonalizationDetailsView: View {
    @ObservedObject var personalizationEngine: PersonalizationEngine
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Current Preferences") {
                    // Would show detailed preference breakdown
                    Text("Communication Style: Friendly")
                    Text("Response Length: Balanced")
                    Text("Formality Level: Professional")
                }
                
                Section("Learning History") {
                    // Would show learning timeline
                    Text("Recent learning events would appear here")
                }
            }
            .navigationTitle("Personalization Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PersonalizationSettingsView()
    }
}