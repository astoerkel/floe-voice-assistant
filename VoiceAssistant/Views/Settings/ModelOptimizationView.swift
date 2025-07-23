import SwiftUI

/// Model optimization settings view for quantization and compression
struct ModelOptimizationView: View {
    @StateObject private var performanceOptimizer = MLPerformanceOptimizer()
    @StateObject private var quantization: ModelQuantization
    @State private var showingClearHistoryAlert = false
    @State private var selectedQualityPreset: QualityPreset = .balanced
    
    enum QualityPreset: String, CaseIterable {
        case highQuality = "High Quality"
        case balanced = "Balanced"
        case efficiency = "Efficiency"
        case custom = "Custom"
        
        var settings: QualitySettings {
            switch self {
            case .highQuality: return .highQuality
            case .balanced: return .balanced
            case .efficiency: return .efficiency
            case .custom: return .balanced // Will be customized
            }
        }
    }
    
    init() {
        let optimizer = MLPerformanceOptimizer()
        self._quantization = StateObject(wrappedValue: ModelQuantization(performanceOptimizer: optimizer))
    }
    
    var body: some View {
        List {
            // Quantization Settings
            Section {
                Toggle("Enable Quantization", isOn: $quantization.isQuantizationEnabled)
                    .onChange(of: quantization.isQuantizationEnabled) { oldValue, newValue in
                        quantization.toggleQuantization()
                    }
                
                if quantization.isQuantizationEnabled {
                    Picker("Quantization Level", selection: $quantization.currentQuantizationLevel) {
                        ForEach(QuantizationLevel.allCases, id: \.self) { level in
                            VStack(alignment: .leading) {
                                Text(level.rawValue)
                                    .font(.headline)
                                Text(level.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: quantization.currentQuantizationLevel) { oldValue, newValue in
                        quantization.updateQuantizationLevel(newValue)
                    }
                    
                    // Expected impact preview
                    if quantization.currentModelSize > 0 {
                        let impact = quantization.simulateQuantizationImpact(
                            originalSize: quantization.currentModelSize,
                            level: quantization.currentQuantizationLevel,
                            precision: quantization.currentPrecisionMode
                        )
                        
                        QuantizationImpactView(result: impact)
                    }
                }
            } header: {
                Text("Model Quantization")
            } footer: {
                Text("Quantization reduces model size and memory usage at the cost of some accuracy.")
            }
            
            // Precision Settings
            if quantization.isQuantizationEnabled {
                Section {
                    Picker("Precision Mode", selection: $quantization.currentPrecisionMode) {
                        ForEach(PrecisionMode.allCases, id: \.self) { mode in
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
                    .onChange(of: quantization.currentPrecisionMode) { oldValue, newValue in
                        quantization.updatePrecisionMode(newValue)
                    }
                } header: {
                    Text("Precision Mode")
                } footer: {
                    Text("Lower precision modes use less memory but may reduce accuracy.")
                }
            }
            
            // Quality vs Performance Settings
            Section {
                Picker("Quality Preset", selection: $selectedQualityPreset) {
                    ForEach(QualityPreset.allCases, id: \.self) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedQualityPreset) { oldValue, newValue in
                    if newValue != .custom {
                        quantization.updateQualitySettings(newValue.settings)
                    }
                }
                
                if selectedQualityPreset == .custom {
                    CustomQualitySettingsView(quantization: quantization)
                } else {
                    QualityPresetInfoView(preset: selectedQualityPreset)
                }
            } header: {
                Text("Quality vs Performance")
            }
            
            // Current Model Information
            Section {
                if quantization.currentModelSize > 0 {
                    HStack {
                        Text("Current Model Size")
                        Spacer()
                        Text(String(format: "%.1f MB", quantization.currentModelSize))
                            .foregroundColor(.secondary)
                    }
                }
                
                let compressionRatio = quantization.averageCompressionRatio()
                if compressionRatio > 1.0 {
                    HStack {
                        Text("Average Compression")
                        Spacer()
                        Text(String(format: "%.1fx", compressionRatio))
                            .foregroundColor(.green)
                    }
                }
                
                HStack {
                    Text("History Entries")
                    Spacer()
                    Text("\(quantization.quantizationHistory.count)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Model Statistics")
            }
            
            // Optimization Recommendations
            Section {
                let recommendations = quantization.getQuantizationRecommendations()
                ForEach(recommendations, id: \.self) { recommendation in
                    RecommendationRow(text: recommendation)
                }
            } header: {
                Text("Optimization Recommendations")
            }
            
            // Data Management
            Section {
                Button("Clear Optimization History") {
                    showingClearHistoryAlert = true
                }
                .foregroundColor(.red)
            } header: {
                Text("Data Management")
            }
        }
        .navigationTitle("Model Optimization")
        .navigationBarTitleDisplayMode(.large)
        .alert("Clear Optimization History", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                quantization.clearHistory()
            }
        } message: {
            Text("This will clear all quantization history data. Optimization recommendations may be less accurate until new data is collected.")
        }
    }
}

// MARK: - Supporting Views

struct QuantizationImpactView: View {
    let result: QuantizationResult
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Expected Impact")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Size Reduction:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f%%", result.sizeReduction * 100))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Quality Impact:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "%.1f%%", result.expectedQualityLoss * 100))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f MB → %.1f MB", result.originalSize, result.quantizedSize))
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Text(String(format: "%.1fx compression", result.compressionRatio))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct CustomQualitySettingsView: View {
    @ObservedObject var quantization: ModelQuantization
    @State private var maxInferenceTime: Double
    @State private var maxMemoryUsage: Double
    @State private var minAccuracyThreshold: Double
    @State private var batteryOptimized: Bool
    
    init(quantization: ModelQuantization) {
        self.quantization = quantization
        self._maxInferenceTime = State(initialValue: quantization.qualitySettings.maxInferenceTime)
        self._maxMemoryUsage = State(initialValue: quantization.qualitySettings.maxMemoryUsage)
        self._minAccuracyThreshold = State(initialValue: quantization.qualitySettings.minAccuracyThreshold)
        self._batteryOptimized = State(initialValue: quantization.qualitySettings.batteryOptimized)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                HStack {
                    Text("Max Inference Time")
                    Spacer()
                    Text(String(format: "%.1fs", maxInferenceTime))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $maxInferenceTime, in: 0.5...10.0, step: 0.1)
                    .onChange(of: maxInferenceTime) { oldValue, newValue in
                        updateSettings()
                    }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Max Memory Usage")
                    Spacer()
                    Text(String(format: "%.0f MB", maxMemoryUsage))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $maxMemoryUsage, in: 100...2000, step: 50)
                    .onChange(of: maxMemoryUsage) { oldValue, newValue in
                        updateSettings()
                    }
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Min Accuracy Threshold")
                    Spacer()
                    Text(String(format: "%.1f%%", minAccuracyThreshold * 100))
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $minAccuracyThreshold, in: 0.5...1.0, step: 0.01)
                    .onChange(of: minAccuracyThreshold) { oldValue, newValue in
                        updateSettings()
                    }
            }
            
            Toggle("Battery Optimized", isOn: $batteryOptimized)
                .onChange(of: batteryOptimized) { oldValue, newValue in
                    updateSettings()
                }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func updateSettings() {
        let settings = QualitySettings(
            maxInferenceTime: maxInferenceTime,
            maxMemoryUsage: maxMemoryUsage,
            minAccuracyThreshold: minAccuracyThreshold,
            batteryOptimized: batteryOptimized
        )
        quantization.updateQualitySettings(settings)
    }
}

struct QualityPresetInfoView: View {
    let preset: ModelOptimizationView.QualityPreset
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(presetDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                QualityMetricView(
                    title: "Performance",
                    value: performanceRating,
                    color: .blue
                )
                
                QualityMetricView(
                    title: "Quality",
                    value: qualityRating,
                    color: .green
                )
                
                QualityMetricView(
                    title: "Efficiency",
                    value: efficiencyRating,
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
        case .highQuality:
            return "Maximum quality with higher resource usage"
        case .balanced:
            return "Good balance between quality and performance"
        case .efficiency:
            return "Maximum efficiency with acceptable quality"
        case .custom:
            return "Custom settings"
        }
    }
    
    private var performanceRating: Double {
        switch preset {
        case .highQuality: return 0.6
        case .balanced: return 0.8
        case .efficiency: return 1.0
        case .custom: return 0.8
        }
    }
    
    private var qualityRating: Double {
        switch preset {
        case .highQuality: return 1.0
        case .balanced: return 0.85
        case .efficiency: return 0.75
        case .custom: return 0.85
        }
    }
    
    private var efficiencyRating: Double {
        switch preset {
        case .highQuality: return 0.5
        case .balanced: return 0.8
        case .efficiency: return 1.0
        case .custom: return 0.8
        }
    }
}

struct QualityMetricView: View {
    let title: String
    let value: Double
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
                    .trim(from: 0, to: value)
                    .stroke(color, lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                
                Text(String(format: "%.0f%%", value * 100))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ModelOptimizationView()
    }
}