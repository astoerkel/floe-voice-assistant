import SwiftUI
import Combine

/// Real-time performance monitoring view with metrics and battery impact visualization
struct PerformanceMonitorView: View {
    @StateObject private var performanceOptimizer = MLPerformanceOptimizer()
    @StateObject private var quantization: ModelQuantization
    @StateObject private var batchProcessor: BatchProcessor
    
    @State private var showingDetails = false
    @State private var selectedMetricsPeriod: MetricsPeriod = .hour
    @State private var isExpanded = false
    
    private enum MetricsPeriod: String, CaseIterable {
        case minute = "1min"
        case hour = "1hr" 
        case day = "24hr"
        
        var description: String {
            switch self {
            case .minute: return "Last Minute"
            case .hour: return "Last Hour"
            case .day: return "Last 24 Hours"
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
        VStack(spacing: 0) {
            // Header with toggle
            headerView
            
            if isExpanded {
                // Main metrics content
                ScrollView {
                    VStack(spacing: 16) {
                        // Performance mode and thermal status
                        systemStatusSection
                        
                        // Real-time metrics
                        metricsSection
                        
                        // Battery impact visualization
                        batteryImpactSection
                        
                        // Processing efficiency
                        efficiencySection
                        
                        // Recommendations
                        recommendationsSection
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                
                Text("Performance Monitor")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Performance status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var systemStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("System Status")
                    .font(.headline)
                Spacer()
                
                Picker("Period", selection: $selectedMetricsPeriod) {
                    ForEach(MetricsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 200)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatusCard(
                    title: "Performance Mode",
                    value: performanceOptimizer.currentMode.rawValue,
                    color: .blue,
                    icon: "speedometer"
                )
                
                StatusCard(
                    title: "Thermal State",
                    value: performanceOptimizer.thermalState.rawValue,
                    color: thermalStateColor,
                    icon: "thermometer"
                )
                
                StatusCard(
                    title: "Battery Level",
                    value: "\(Int(performanceOptimizer.batteryLevel * 100))%",
                    color: batteryColor,
                    icon: batteryIcon
                )
                
                StatusCard(
                    title: "Processing",
                    value: batchProcessor.isProcessing ? "Active" : "Idle",
                    color: batchProcessor.isProcessing ? .orange : .green,
                    icon: "cpu"
                )
            }
        }
    }
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-time Metrics")
                .font(.headline)
            
            VStack(spacing: 16) {
                // Throughput chart
                MetricChart(
                    title: "Throughput",
                    value: String(format: "%.1f req/s", batchProcessor.averageThroughput),
                    data: throughputData,
                    color: .blue
                )
                
                // Latency chart
                MetricChart(
                    title: "Average Latency",
                    value: String(format: "%.2fs", batchProcessor.getAverageLatency()),
                    data: latencyData,
                    color: .orange
                )
                
                // Queue size indicator
                HStack {
                    Text("Queue Size")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(batchProcessor.queuedRequestsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(queueSizeColor)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
    }
    
    private var batteryImpactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Battery Impact")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Battery drain rate
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Drain Rate")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(batteryDrainText)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(batteryDrainColor)
                    }
                    
                    Spacer()
                    
                    // Battery visualization
                    BatteryVisualization(
                        level: performanceOptimizer.batteryLevel,
                        isCharging: performanceOptimizer.isCharging,
                        drainRate: estimatedBatteryDrain
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                
                // Energy efficiency gauge
                EnergyEfficiencyGauge(
                    efficiency: performanceOptimizer.averageEfficiency() ?? 0.5,
                    thermalState: performanceOptimizer.thermalState
                )
            }
        }
    }
    
    private var efficiencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Efficiency")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Overall efficiency
                EfficiencyIndicator(
                    title: "Overall Efficiency",
                    value: performanceOptimizer.averageEfficiency() ?? 0.5,
                    color: efficiencyColor
                )
                
                // Model loading overhead
                HStack {
                    Text("Model Loading Overhead")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(String(format: "%.2fs", batchProcessor.modelLoadingOverhead))
                        .font(.headline)
                        .foregroundColor(overheadColor)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                
                // Quantization impact
                if quantization.isQuantizationEnabled {
                    HStack {
                        Text("Compression Ratio")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text(String(format: "%.1fx", quantization.averageCompressionRatio()))
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
            
            VStack(spacing: 8) {
                let allRecommendations = performanceOptimizer.getPerformanceRecommendations() +
                                       quantization.getQuantizationRecommendations() +
                                       batchProcessor.getProcessingRecommendations()
                
                ForEach(Array(Set(allRecommendations)).prefix(3), id: \.self) { recommendation in
                    RecommendationCard(text: recommendation)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatusCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct MetricChart: View {
    let title: String
    let value: String
    let data: [Double]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            // Simple line chart representation
            GeometryReader { geometry in
                Path { path in
                    guard !data.isEmpty else { return }
                    
                    let maxValue = data.max() ?? 1.0
                    let minValue = data.min() ?? 0.0
                    let range = maxValue - minValue
                    
                    let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))
                    
                    path.move(to: CGPoint(
                        x: 0,
                        y: geometry.size.height * (1 - CGFloat((data[0] - minValue) / range))
                    ))
                    
                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height * (1 - CGFloat((value - minValue) / range))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(color, lineWidth: 2)
            }
            .frame(height: 60)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct BatteryVisualization: View {
    let level: Float
    let isCharging: Bool
    let drainRate: Double
    
    var body: some View {
        HStack(spacing: 8) {
            // Battery icon
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.primary, lineWidth: 1)
                    .frame(width: 30, height: 16)
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary)
                    .frame(width: 2, height: 6)
                    .offset(x: 16)
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(batteryFillColor)
                    .frame(width: CGFloat(level) * 26, height: 12)
                    .offset(x: -2 + CGFloat(level) * 13)
            }
            
            // Charging indicator
            if isCharging {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
            
            // Drain rate indicator
            if !isCharging {
                HStack(spacing: 2) {
                    Image(systemName: drainRate > 0.5 ? "arrow.down" : "minus")
                        .foregroundColor(drainRate > 0.5 ? .red : .green)
                        .font(.caption2)
                    
                    Text(String(format: "%.1f%%/h", drainRate * 100))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var batteryFillColor: Color {
        if level > 0.5 { return .green }
        if level > 0.2 { return .orange }
        return .red
    }
}

struct EnergyEfficiencyGauge: View {
    let efficiency: Double
    let thermalState: ThermalState
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Energy Efficiency")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(String(format: "%.1f%%", efficiency * 100))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(efficiencyColor)
            }
            
            // Gauge visualization
            GeometryReader { geometry in
                ZStack {
                    // Background arc
                    Circle()
                        .trim(from: 0.25, to: 1.0)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .rotationEffect(.degrees(90))
                    
                    // Progress arc
                    Circle()
                        .trim(from: 0.25, to: 0.25 + (0.75 * efficiency))
                        .stroke(efficiencyColor, lineWidth: 8)
                        .rotationEffect(.degrees(90))
                        .animation(.easeInOut(duration: 1.0), value: efficiency)
                }
            }
            .frame(height: 100)
            
            // Thermal warning
            if thermalState.shouldThrottle {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("Thermal throttling active")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var efficiencyColor: Color {
        if efficiency > 0.8 { return .green }
        if efficiency > 0.6 { return .orange }
        return .red
    }
}

struct EfficiencyIndicator: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * value, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: value)
                }
            }
            .frame(width: 60, height: 8)
            
            Text(String(format: "%.1f%%", value * 100))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 50, alignment: .trailing)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct RecommendationCard: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb")
                .foregroundColor(.blue)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }
}

// MARK: - Computed Properties Extension

extension PerformanceMonitorView {
    private var statusColor: Color {
        let efficiency = performanceOptimizer.averageEfficiency() ?? 0.5
        if efficiency > 0.8 { return .green }
        if efficiency > 0.6 { return .orange }
        return .red
    }
    
    private var statusText: String {
        let efficiency = performanceOptimizer.averageEfficiency() ?? 0.5
        if efficiency > 0.8 { return "Optimal" }
        if efficiency > 0.6 { return "Good" }
        return "Needs Attention"
    }
    
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
    
    private var queueSizeColor: Color {
        if batchProcessor.queuedRequestsCount > 10 { return .red }
        if batchProcessor.queuedRequestsCount > 5 { return .orange }
        return .primary
    }
    
    private var batteryDrainText: String {
        if performanceOptimizer.isCharging { return "Charging" }
        return String(format: "%.1f%%/hr", estimatedBatteryDrain * 100)
    }
    
    private var batteryDrainColor: Color {
        if performanceOptimizer.isCharging { return .green }
        if estimatedBatteryDrain > 0.5 { return .red }
        if estimatedBatteryDrain > 0.2 { return .orange }
        return .green
    }
    
    private var estimatedBatteryDrain: Double {
        // Simulate battery drain calculation based on performance metrics
        let baselineDrain = 0.1 // 10% per hour baseline
        return baselineDrain * (performanceOptimizer.thermalState.shouldThrottle ? 1.5 : 1.0)
    }
    
    private var efficiencyColor: Color {
        let efficiency = performanceOptimizer.averageEfficiency() ?? 0.5
        if efficiency > 0.8 { return .green }
        if efficiency > 0.6 { return .orange }
        return .red
    }
    
    private var overheadColor: Color {
        if batchProcessor.modelLoadingOverhead > 2.0 { return .red }
        if batchProcessor.modelLoadingOverhead > 1.0 { return .orange }
        return .green
    }
    
    // Sample data for charts (in real implementation, this would come from actual metrics)
    private var throughputData: [Double] {
        return (0..<20).map { _ in Double.random(in: 0...10) }
    }
    
    private var latencyData: [Double] {
        return (0..<20).map { _ in Double.random(in: 0.1...2.0) }
    }
}

#Preview {
    PerformanceMonitorView()
        .padding()
        .background(Color(.systemGroupedBackground))
}