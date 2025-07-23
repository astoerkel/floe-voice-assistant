import SwiftUI

struct EnhancedSpeechSettingsView: View {
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @State private var showVocabularyManager = false
    @State private var showPatternLearning = false
    @State private var showPrivacySettings = false
    @State private var customTerm = ""
    @State private var selectedDomain = VocabularyManager.VocabularyDomain.custom
    
    var body: some View {
        NavigationView {
            List {
                // Enhanced Features Section
                Section("Enhanced Features") {
                    enhancedFeaturesToggle
                    if speechRecognizer.isEnhanced {
                        processingModeSelector
                        enhancementStatusView
                    }
                }
                
                // Vocabulary Management
                if speechRecognizer.isEnhanced {
                    Section("Vocabulary Management") {
                        vocabularyStatsView
                        addCustomTermSection
                        vocabularyManagerButton
                    }
                    
                    // Pattern Learning
                    Section("Pattern Learning") {
                        patternLearningStatusView
                        patternLearningButton
                        resetLearningButton
                    }
                    
                    // Privacy & Data
                    Section("Privacy & Data") {
                        privacyStatusView
                        privacySettingsButton
                        exportDataButton
                    }
                }
            }
            .navigationTitle("Enhanced Speech")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showVocabularyManager) {
            VocabularyManagerView(vocabularyManager: speechRecognizer.enhancedSpeechRecognizer.vocabularyManager)
        }
        .sheet(isPresented: $showPatternLearning) {
            PatternLearningView(patternLearning: speechRecognizer.enhancedSpeechRecognizer.patternLearning)
        }
        .sheet(isPresented: $showPrivacySettings) {
            SpeechPrivacyView(speechRecognizer: speechRecognizer)
        }
    }
    
    private var enhancedFeaturesToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hybrid Mode")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("Enhanced on-device processing with server fallback")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $speechRecognizer.useHybridMode)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
    }
    
    private var processingModeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processing Mode")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Picker("Processing Mode", selection: Binding(
                get: { speechRecognizer.processingMode },
                set: { speechRecognizer.setProcessingMode($0) }
            )) {
                ForEach(EnhancedSpeechRecognizer.ProcessingMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var enhancementStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Enhancements")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                confidenceIndicator
            }
            
            if !speechRecognizer.enhancedSpeechRecognizer.enhancements.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(speechRecognizer.enhancedSpeechRecognizer.enhancements, id: \.self) { enhancement in
                        enhancementBadge(enhancement)
                    }
                }
            } else {
                Text("No enhancements active")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Text("Confidence:")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(Int(speechRecognizer.confidenceScore * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(confidenceColor)
        }
    }
    
    private var confidenceColor: Color {
        switch speechRecognizer.confidenceScore {
        case 0.9...1.0: return .green
        case 0.75..<0.9: return .blue
        case 0.5..<0.75: return .orange
        default: return .red
        }
    }
    
    private func enhancementBadge(_ enhancement: String) -> some View {
        Text(enhancement)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
    }
    
    private var vocabularyStatsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let stats = speechRecognizer.getVocabularyStats() {
                HStack {
                    Text("Total Terms")
                    Spacer()
                    Text("\(stats.totalTerms)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Custom Terms")
                    Spacer()
                    Text("\(stats.customTerms)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Contact Names")
                    Spacer()
                    Text("\(stats.contactNames)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Corrections Learned")
                    Spacer()
                    Text("\(stats.userCorrections)")
                        .fontWeight(.semibold)
                }
            } else {
                Text("Vocabulary statistics unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .font(.caption)
    }
    
    private var addCustomTermSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Enter custom term", text: $customTerm)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Add") {
                    addCustomTerm()
                }
                .disabled(customTerm.isEmpty)
            }
            
            Picker("Domain", selection: $selectedDomain) {
                ForEach(VocabularyManager.VocabularyDomain.allCases, id: \.self) { domain in
                    Text(domain.rawValue.capitalized).tag(domain)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    private var vocabularyManagerButton: some View {
        Button(action: { showVocabularyManager = true }) {
            HStack {
                Image(systemName: "text.book.closed")
                Text("Manage Vocabulary")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var patternLearningStatusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Learning Status")
                Spacer()
                Circle()
                    .fill(speechRecognizer.enhancedSpeechRecognizer.patternLearning.isLearningEnabled ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(speechRecognizer.enhancedSpeechRecognizer.patternLearning.isLearningEnabled ? "Active" : "Disabled")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Patterns Learned")
                Spacer()
                Text("\(speechRecognizer.enhancedSpeechRecognizer.patternLearning.patternCount)")
                    .fontWeight(.semibold)
            }
            
            HStack {
                Text("Adaptation Accuracy")
                Spacer()
                Text("\(Int(speechRecognizer.enhancedSpeechRecognizer.patternLearning.adaptationAccuracy * 100))%")
                    .fontWeight(.semibold)
                    .foregroundColor(speechRecognizer.enhancedSpeechRecognizer.patternLearning.adaptationAccuracy > 0.8 ? .green : .orange)
            }
        }
        .font(.caption)
    }
    
    private var patternLearningButton: some View {
        Button(action: { showPatternLearning = true }) {
            HStack {
                Image(systemName: "brain.head.profile")
                Text("Pattern Learning Details")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var resetLearningButton: some View {
        Button(action: resetLearning) {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.red)
                Text("Reset Learning Data")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var privacyStatusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.green)
                Text("All data processed locally")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            HStack {
                Image(systemName: "key")
                    .foregroundColor(.blue)
                Text("AES-256-GCM encryption")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            HStack {
                Image(systemName: "icloud.slash")
                    .foregroundColor(.orange)
                Text("No cloud synchronization")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
        }
    }
    
    private var privacySettingsButton: some View {
        Button(action: { showPrivacySettings = true }) {
            HStack {
                Image(systemName: "hand.raised")
                Text("Privacy Settings")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var exportDataButton: some View {
        Button(action: exportPrivacyReport) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export Privacy Report")
                Spacer()
            }
        }
    }
    
    private func addCustomTerm() {
        guard !customTerm.isEmpty else { return }
        
        speechRecognizer.addCustomVocabulary(terms: [customTerm], domain: selectedDomain)
        customTerm = ""
        
        // Show confirmation with haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func resetLearning() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        speechRecognizer.resetLearningData()
    }
    
    private func exportPrivacyReport() {
        let report = speechRecognizer.exportPrivacyReport()
        
        // Convert to JSON string for sharing
        if let jsonData = try? JSONSerialization.data(withJSONObject: report, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            let activityVC = UIActivityViewController(
                activityItems: [jsonString],
                applicationActivities: nil
            )
            
            // Present the share sheet
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        
        let width = proposal.width ?? 0
        let height = rows.reduce(0) { result, row in
            result + row.maxHeight + spacing
        } - spacing
        
        return CGSize(width: width, height: max(0, height))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y + (row.maxHeight - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let width = proposal.width ?? .infinity
        var rows: [Row] = []
        var currentRow = Row()
        var x: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > width && !currentRow.subviews.isEmpty {
                rows.append(currentRow)
                currentRow = Row()
                x = 0
            }
            
            currentRow.add(subview: subview, width: size.width, height: size.height)
            x += size.width + spacing
        }
        
        if !currentRow.subviews.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    private struct Row {
        var subviews: [LayoutSubview] = []
        var maxHeight: CGFloat = 0
        
        mutating func add(subview: LayoutSubview, width: CGFloat, height: CGFloat) {
            subviews.append(subview)
            maxHeight = max(maxHeight, height)
        }
    }
}

// MARK: - Preview

struct EnhancedSpeechSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedSpeechSettingsView(speechRecognizer: SpeechRecognizer())
    }
}