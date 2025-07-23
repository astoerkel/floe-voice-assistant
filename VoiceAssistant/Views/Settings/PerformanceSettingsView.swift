import SwiftUI

/// Performance settings view with real-time monitoring and optimization controls
struct PerformanceSettingsView: View {
    @StateObject private var performanceOptimizer = MLPerformanceOptimizer()
    @StateObject private var quantization: ModelQuantization
    @StateObject private var batchProcessor: BatchProcessor
    @State private var showingClearHistoryAlert = false
    
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
            // Real-time Performance Monitor
            Section {
                PerformanceMonitorView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            
            // Performance Mode Selection
            Section {
                Picker("Performance Mode", selection: $performanceOptimizer.currentMode) {
                    ForEach(PerformanceMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.rawValue)
                                .font(.headline)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: performanceOptimizer.currentMode) { oldValue, newValue in
                    performanceOptimizer.setPerformanceMode(newValue)
                }
            } header: {
                Text("Performance Mode")
            } footer: {
                Text("Select the performance mode that best fits your usage patterns and battery preferences.")
            }
            
            // System Status
            Section {
                StatusRow(
                    title: "Thermal State",
                    value: performanceOptimizer.thermalState.rawValue,
                    color: thermalStateColor,
                    icon: "thermometer"
                )
                
                StatusRow(
                    title: "Battery Level",
                    value: "\(Int(performanceOptimizer.batteryLevel * 100))%",
                    color: batteryColor,
                    icon: batteryIcon
                )
                
                if let efficiency = performanceOptimizer.averageEfficiency() {
                    StatusRow(
                        title: "System Efficiency",
                        value: "\(Int(efficiency * 100))%",
                        color: efficiencyColor(efficiency),
                        icon: "speedometer"
                    )
                }
                
                StatusRow(
                    title: "Processing Queue",
                    value: "\(batchProcessor.queuedRequestsCount) requests",
                    color: queueColor,
                    icon: "list.bullet"
                )
            } header: {
                Text("System Status")
            }
            
            // Performance Metrics
            Section {
                if let metrics = performanceOptimizer.currentMetrics {
                    MetricRow(
                        title: "Last Inference Time",
                        value: String(format: "%.2fs", metrics.inferenceTime),
                        description: "Time for last processing operation"
                    )
                    
                    MetricRow(
                        title: "Memory Usage",
                        value: String(format: "%.1f MB", metrics.memoryUsage),
                        description: "Current memory consumption"
                    )
                    
                    MetricRow(
                        title: "Success Rate",
                        value: String(format: "%.1f%%", metrics.successRate * 100),
                        description: "Processing success rate"
                    )
                }
                
                MetricRow(
                    title: "Average Throughput",
                    value: String(format: "%.1f req/s", batchProcessor.averageThroughput),
                    description: "Requests processed per second"
                )
                
                MetricRow(
                    title: "Model Loading Overhead",
                    value: String(format: "%.2fs", batchProcessor.modelLoadingOverhead),
                    description: "Time spent loading models"
                )
            } header: {
                Text("Performance Metrics")
            }
            
            // Optimization Recommendations
            Section {
                let recommendations = performanceOptimizer.getPerformanceRecommendations()
                ForEach(recommendations, id: \.self) { recommendation in
                    RecommendationRow(text: recommendation)
                }
            } header: {
                Text("Optimization Recommendations")
            }
            
            // Performance History Management
            Section {
                Button("Clear Performance History") {
                    showingClearHistoryAlert = true
                }
                .foregroundColor(.red)
                
                if !performanceOptimizer.performanceHistory.isEmpty {
                    HStack {
                        Text("History Entries")
                        Spacer()
                        Text("\(performanceOptimizer.performanceHistory.count)")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Data Management")
            } footer: {
                Text("Performance history is used to optimize settings automatically.")
            }
        }
        .navigationTitle("Performance Monitor")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear Performance History", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                performanceOptimizer.clearHistory()
                batchProcessor.clearHistory()
            }
        } message: {
            Text("This will clear all performance history data. Optimization recommendations may be less accurate until new data is collected.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var thermalStateColor: Color {
        switch performanceOptimizer.thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
    
    private var batteryColor: Color {
        if performanceOptimizer.batteryLevel > 0.5 { return .green }
        if performanceOptimizer.batteryLevel > 0.2 { return .orange }
        return .red
    }
    
    private var batteryIcon: String {
        if performanceOptimizer.isCharging { return "battery.100.bolt" }
        if performanceOptimizer.batteryLevel > 0.75 { return "battery.100" }
        if performanceOptimizer.batteryLevel > 0.5 { return "battery.75" }
        if performanceOptimizer.batteryLevel > 0.25 { return "battery.50" }
        return "battery.25"
    }
    
    private var queueColor: Color {
        if batchProcessor.queuedRequestsCount > 10 { return .red }
        if batchProcessor.queuedRequestsCount > 5 { return .orange }
        return .primary
    }
    
    private func efficiencyColor(_ efficiency: Double) -> Color {
        if efficiency > 0.8 { return .green }
        if efficiency > 0.6 { return .orange }
        return .red
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                
                Spacer()
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct RecommendationRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb")
                .foregroundColor(.blue)
                .font(.caption)
                .padding(.top, 2)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        PerformanceSettingsView()
    }
}