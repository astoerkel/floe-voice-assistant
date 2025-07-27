import SwiftUI

/// Batch processing settings and optimization view
struct BatchProcessingSettingsView: View {
    @StateObject private var performanceOptimizer = MLPerformanceOptimizer()
    @StateObject private var quantization: ModelQuantization
    @StateObject private var batchProcessor: BatchProcessor
    @State private var showingClearHistoryAlert = false
    @State private var selectedPreset: BatchPreset = .balanced
    
    enum BatchPreset: String, CaseIterable {
        case lowLatency = "Low Latency"
        case balanced = "Balanced"
        case highThroughput = "High Throughput"
        case custom = "Custom"
        
        var configuration: BatchConfiguration {
            switch self {
            case .lowLatency: return .lowLatency
            case .balanced: return .balanced
            case .highThroughput: return .highThroughput
            case .custom: return .balanced // Will be customized
            }
        }
    }
    
    init() {
        let optimizer = MLPerformanceOptimizer()
        let quantizationManager = ModelQuantization(performanceOptimizer: optimizer)
        self._quantization = StateObject(wrappedValue: quantizationManager)
        self._batchProcessor = StateObject(wrappedValue: BatchProcessor(
            performanceOptimizer: optimizer,
            quantization: quantizationManager
        ))
    }
    
    var body: some View {
        List {
            // Current Processing Status
            Section {
                ProcessingStatusView(batchProcessor: batchProcessor)
            } header: {
                Text("Current Status")
            }
            
            // Batch Configuration Presets
            Section {
                Picker("Processing Mode", selection: $selectedPreset) {
                    ForEach(BatchPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPreset) { oldValue, newValue in
                    if newValue != .custom {
                        batchProcessor.updateConfiguration(newValue.configuration)
                    }
                }
                
                if selectedPreset == .custom {
                    CustomBatchConfigurationView(batchProcessor: batchProcessor)
                } else {
                    BatchPresetInfoView(preset: selectedPreset)
                }
            } header: {
                Text("Batch Processing Configuration")
            } footer: {
                Text("Choose the processing mode that best fits your usage patterns.")
            }
            
            // Queue Management
            Section {
                QueueManagementView(batchProcessor: batchProcessor)
            } header: {
                Text("Queue Management")
            }
            
            // Performance Metrics
            Section {
                BatchPerformanceMetricsView(batchProcessor: batchProcessor)
            } header: {
                Text("Performance Metrics")
            }
            
            // Processing Recommendations
            Section {
                let recommendations = batchProcessor.getProcessingRecommendations()
                ForEach(recommendations, id: \.self) { recommendation in
                    RecommendationRow(text: recommendation)
                }
            } header: {
                Text("Optimization Recommendations")
            }
            
            // Advanced Settings
            Section {
                AdvancedBatchSettingsView(batchProcessor: batchProcessor)
            } header: {
                Text("Advanced Settings")
            }
            
            // Data Management
            Section {
                Button("Clear Processing History") {
                    showingClearHistoryAlert = true
                }
                .foregroundColor(.red)
                
                HStack {
                    Text("History Entries")
                    Spacer()
                    Text("\(batchProcessor.processingMetrics.count)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Data Management")
            }
        }
        .navigationTitle("Batch Processing")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear Processing History", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                batchProcessor.clearHistory()
            }
        } message: {
            Text("This will clear all processing history data. Performance recommendations may be less accurate until new data is collected.")
        }
    }
}

// MARK: - Supporting Views

struct ProcessingStatusView: View {
    @ObservedObject var batchProcessor: BatchProcessor
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StatusIndicator(
                    title: "Processing Status",
                    value: batchProcessor.isProcessing ? "Active" : "Idle",
                    color: batchProcessor.isProcessing ? .orange : .green,
                    icon: batchProcessor.isProcessing ? "cpu" : "checkmark.circle"
                )
                
                Spacer()
                
                StatusIndicator(
                    title: "Queue Size",
                    value: "\(batchProcessor.queuedRequestsCount)",
                    color: queueColor(batchProcessor.queuedRequestsCount),
                    icon: "list.bullet"
                )
            }
            
            HStack {
                StatusIndicator(
                    title: "Throughput",
                    value: String(format: "%.1f req/s", batchProcessor.averageThroughput),
                    color: .blue,
                    icon: "speedometer"
                )
                
                Spacer()
                
                StatusIndicator(
                    title: "Model Loading",
                    value: String(format: "%.2fs", batchProcessor.modelLoadingOverhead),
                    color: overheadColor(batchProcessor.modelLoadingOverhead),
                    icon: "arrow.down.circle"
                )
            }
        }
    }
    
    private func queueColor(_ count: Int) -> Color {
        if count > 10 { return .red }
        if count > 5 { return .orange }
        return .primary
    }
    
    private func overheadColor(_ overhead: TimeInterval) -> Color {
        if overhead > 2.0 { return .red }
        if overhead > 1.0 { return .orange }
        return .green
    }
}

struct StatusIndicator: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct CustomBatchConfigurationView: View {
    @ObservedObject var batchProcessor: BatchProcessor
    @State private var maxBatchSize: Double
    @State private var maxWaitTime: Double
    @State private var minBatchSize: Double
    @State private var enableAdaptiveBatching: Bool
    
    init(batchProcessor: BatchProcessor) {
        self.batchProcessor = batchProcessor
        self._maxBatchSize = State(initialValue: Double(batchProcessor.configuration.maxBatchSize))
        self._maxWaitTime = State(initialValue: batchProcessor.configuration.maxWaitTime)
        self._minBatchSize = State(initialValue: Double(batchProcessor.configuration.minBatchSize))
        self._enableAdaptiveBatching = State(initialValue: batchProcessor.configuration.enableAdaptiveBatching)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                HStack {
                    Text("Max Batch Size")
                    Spacer()
                    Text("\(Int(maxBatchSize))")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $maxBatchSize, in: 1...64, step: 1)
                    .onChange(of: maxBatchSize) { oldValue, newValue in
                        updateConfiguration()
                    }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Max Wait Time")
                    Spacer()
                    Text(String(format: "%.1fs", maxWaitTime))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $maxWaitTime, in: 0.1...10.0, step: 0.1)
                    .onChange(of: maxWaitTime) { oldValue, newValue in
                        updateConfiguration()
                    }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Min Batch Size")
                    Spacer()
                    Text("\(Int(minBatchSize))")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $minBatchSize, in: 1...16, step: 1)
                    .onChange(of: minBatchSize) { oldValue, newValue in
                        updateConfiguration()
                    }
            }
            
            Toggle("Adaptive Batching", isOn: $enableAdaptiveBatching)
                .onChange(of: enableAdaptiveBatching) { oldValue, newValue in
                    updateConfiguration()
                }
            
            if enableAdaptiveBatching {
                Text("Automatically adjust batch sizes based on system conditions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func updateConfiguration() {
        let config = BatchConfiguration(
            maxBatchSize: Int(maxBatchSize),
            maxWaitTime: maxWaitTime,
            minBatchSize: Int(minBatchSize),
            enableAdaptiveBatching: enableAdaptiveBatching
        )
        batchProcessor.updateConfiguration(config)
    }
}

struct BatchPresetInfoView: View {
    let preset: BatchProcessingSettingsView.BatchPreset
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(presetDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                PresetMetricView(
                    title: "Latency",
                    rating: latencyRating,
                    color: .blue
                )
                
                PresetMetricView(
                    title: "Throughput",
                    rating: throughputRating,
                    color: .green
                )
                
                PresetMetricView(
                    title: "Efficiency",
                    rating: efficiencyRating,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var presetDescription: String {
        switch preset {
        case .lowLatency:
            return "Minimizes response time with smaller batch sizes"
        case .balanced:
            return "Good balance between latency and throughput"
        case .highThroughput:
            return "Maximizes throughput with larger batch sizes"
        case .custom:
            return "Custom configuration"
        }
    }
    
    private var latencyRating: Double {
        switch preset {
        case .lowLatency: return 1.0
        case .balanced: return 0.8
        case .highThroughput: return 0.6
        case .custom: return 0.8
        }
    }
    
    private var throughputRating: Double {
        switch preset {
        case .lowLatency: return 0.6
        case .balanced: return 0.8
        case .highThroughput: return 1.0
        case .custom: return 0.8
        }
    }
    
    private var efficiencyRating: Double {
        switch preset {
        case .lowLatency: return 0.7
        case .balanced: return 0.9
        case .highThroughput: return 0.8
        case .custom: return 0.8
        }
    }
}

struct PresetMetricView: View {
    let title: String
    let rating: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: rating)
                    .stroke(color, lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                
                Text(ratingText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
        }
    }
    
    private var ratingText: String {
        if rating >= 0.9 { return "★★★" }
        if rating >= 0.7 { return "★★☆" }
        return "★☆☆"
    }
}

struct QueueManagementView: View {
    @ObservedObject var batchProcessor: BatchProcessor
    
    var body: some View {
        VStack(spacing: 12) {
            let stats = batchProcessor.getQueueStatistics()
            
            HStack {
                QueueStatView(
                    title: "Total Requests",
                    value: "\(stats["totalRequests"] as? Int ?? 0)",
                    color: .blue
                )
                
                Spacer()
                
                QueueStatView(
                    title: "Model Types",
                    value: "\(stats["modelTypes"] as? Int ?? 0)",
                    color: .green
                )
            }
            
            // Priority breakdown
            if let priorityBreakdown = stats["priorityBreakdown"] as? [RequestPriority: Int] {
                VStack(spacing: 8) {
                    Text("Priority Breakdown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(RequestPriority.allCases.reversed(), id: \.self) { priority in
                        let count = priorityBreakdown[priority] ?? 0
                        PriorityRow(priority: priority, count: count)
                    }
                }
            }
            
            // Queue actions
            HStack(spacing: 12) {
                Button("Force Process All") {
                    batchProcessor.forceBatchProcessing()
                }
                .buttonStyle(.bordered)
                .disabled(batchProcessor.queuedRequestsCount == 0)
                
                Spacer()
                
                Button("Clear Queue") {
                    // Implementation would clear the queue
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .disabled(batchProcessor.queuedRequestsCount == 0)
            }
        }
    }
}

struct QueueStatView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct PriorityRow: View {
    let priority: RequestPriority
    let count: Int
    
    var body: some View {
        HStack {
            Text(priority.description)
                .font(.caption)
            
            Spacer()
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(priorityColor)
        }
    }
    
    private var priorityColor: Color {
        switch priority {
        case .critical: return .red
        case .high: return .orange
        case .normal: return .blue
        case .low: return .gray
        }
    }
}

struct BatchPerformanceMetricsView: View {
    @ObservedObject var batchProcessor: BatchProcessor
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                MetricView(
                    title: "Avg Throughput",
                    value: String(format: "%.1f req/s", batchProcessor.averageThroughput),
                    color: .blue
                )
                
                Spacer()
                
                MetricView(
                    title: "Avg Latency",
                    value: String(format: "%.2fs", batchProcessor.getAverageLatency()),
                    color: .orange
                )
            }
            
            // Performance chart placeholder
            VStack(spacing: 8) {
                HStack {
                    Text("Processing History")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("Last 10 batches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Simple performance visualization
                GeometryReader { geometry in
                    let metrics = Array(batchProcessor.processingMetrics.suffix(10))
                    
                    Path { path in
                        guard !metrics.isEmpty else { return }
                        
                        let maxThroughput = metrics.map { $0.throughput }.max() ?? 1.0
                        let stepX = geometry.size.width / CGFloat(max(metrics.count - 1, 1))
                        
                        path.move(to: CGPoint(
                            x: 0,
                            y: geometry.size.height * (1 - CGFloat(metrics[0].throughput / maxThroughput))
                        ))
                        
                        for (index, metric) in metrics.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = geometry.size.height * (1 - CGFloat(metric.throughput / maxThroughput))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
                .frame(height: 60)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct AdvancedBatchSettingsView: View {
    @ObservedObject var batchProcessor: BatchProcessor
    @State private var enablePriorityQueue = true
    @State private var enableModelCaching = true
    @State private var enableLoadBalancing = true
    
    var body: some View {
        VStack(spacing: 12) {
            Toggle("Priority Queue", isOn: $enablePriorityQueue)
            
            if enablePriorityQueue {
                Text("Process higher priority requests first.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("Model Caching", isOn: $enableModelCaching)
            
            if enableModelCaching {
                Text("Cache loaded models to reduce loading overhead.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Toggle("Load Balancing", isOn: $enableLoadBalancing)
            
            if enableLoadBalancing {
                Text("Distribute requests across available compute units.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BatchProcessingSettingsView()
    }
}