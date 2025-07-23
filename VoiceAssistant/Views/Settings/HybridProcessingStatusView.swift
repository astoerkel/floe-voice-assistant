import SwiftUI
import Charts

/// Status view showing hybrid processing analytics and controls
public struct HybridProcessingStatusView: View {
    
    // MARK: - Dependencies
    @StateObject private var hybridProcessor = HybridProcessor(offlineProcessor: OfflineProcessor())
    @StateObject private var analytics = HybridProcessingAnalytics.shared
    
    // MARK: - State
    @State private var showingAnalyticsDetail = false
    @State private var showingExportSheet = false
    @State private var exportData: Data?
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current processing status
                    currentStatusSection
                    
                    // Analytics overview
                    analyticsOverviewSection
                    
                    // Processing distribution chart
                    distributionChartSection
                    
                    // Weekly trends
                    weeklyTrendsSection
                    
                    // Cost savings
                    costSavingsSection
                    
                    // Performance metrics
                    performanceMetricsSection
                    
                    // Processing settings
                    settingsSection
                }
                .padding()
            }
            .navigationTitle("Hybrid Processing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("View Detailed Analytics") {
                            showingAnalyticsDetail = true
                        }
                        
                        Button("Export Data") {
                            exportAnalyticsData()
                        }
                        
                        Button("Reset Analytics", role: .destructive) {
                            analytics.clearAnalyticsData()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAnalyticsDetail) {
            DetailedAnalyticsView()
        }
        .sheet(isPresented: $showingExportSheet) {
            if let data = exportData {
                ShareSheet(activityItems: [data])
            }
        }
    }
    
    // MARK: - Current Status Section
    
    private var currentStatusSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Status")
                    .font(.headline)
                Spacer()
            }
            
            ProcessingLocationIndicator(
                location: hybridProcessor.currentProcessingLocation,
                confidence: 0.85,
                isProcessing: hybridProcessor.isProcessing,
                compact: false
            )
            
            // Capabilities overview
            capabilitiesOverview
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var capabilitiesOverview: some View {
        let capabilities = hybridProcessor.getCurrentCapabilities()
        
        return HStack(spacing: 16) {
            capabilityItem(
                title: "On-Device",
                isAvailable: capabilities.onDeviceAvailable,
                icon: "iphone",
                color: .green
            )
            
            capabilityItem(
                title: "Server",
                isAvailable: capabilities.serverAvailable,
                icon: "cloud",
                color: .blue
            )
            
            capabilityItem(
                title: "Hybrid",
                isAvailable: capabilities.hybridAvailable,
                icon: "arrow.triangle.2.circlepath",
                color: .purple
            )
        }
    }
    
    private func capabilityItem(title: String, isAvailable: Bool, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isAvailable ? color : .gray)
            
            Text(title)
                .font(.caption)
                .foregroundColor(isAvailable ? .primary : .secondary)
            
            Circle()
                .fill(isAvailable ? color : Color.gray)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Analytics Overview
    
    private var analyticsOverviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Analytics")
                    .font(.headline)
                Spacer()
                Button("View Details") {
                    showingAnalyticsDetail = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            let stats = analytics.currentStats
            
            HStack(spacing: 16) {
                analyticsItem(
                    title: "Total Requests",
                    value: "\(stats.totalProcessings)",
                    subtitle: "\(Int(stats.successRate * 100))% success",
                    color: .blue
                )
                
                analyticsItem(
                    title: "On-Device",
                    value: "\(Int(stats.onDeviceRatio * 100))%",
                    subtitle: "\(stats.onDeviceCount) requests",
                    color: .green
                )
                
                analyticsItem(
                    title: "Avg Confidence",
                    value: "\(Int(stats.averageConfidence * 100))%",
                    subtitle: "\(String(format: "%.2f", stats.averageProcessingTime))s avg",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func analyticsItem(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Distribution Chart
    
    private var distributionChartSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Processing Distribution")
                    .font(.headline)
                Spacer()
            }
            
            let stats = analytics.currentStats
            let data = [
                ChartData(category: "On-Device", value: Double(stats.onDeviceCount), color: .green),
                ChartData(category: "Server", value: Double(stats.serverCount), color: .blue),
                ChartData(category: "Hybrid", value: Double(stats.hybridCount), color: .purple),
                ChartData(category: "Fallback", value: Double(stats.fallbackCount), color: .orange)
            ].filter { $0.value > 0 }
            
            if #available(iOS 16.0, *), !data.isEmpty {
                Chart(data, id: \.category) { item in
                    SectorMark(
                        angle: .value("Count", item.value),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .opacity(0.8)
                }
                .frame(height: 200)
                .chartLegend(position: .bottom, alignment: .center, spacing: 20)
            } else {
                // Fallback for iOS 15
                distributionBars(data: data)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func distributionBars(data: [ChartData]) -> some View {
        VStack(spacing: 8) {
            ForEach(data, id: \.category) { item in
                HStack {
                    Text(item.category)
                        .font(.caption)
                        .frame(width: 80, alignment: .leading)
                    
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.color.opacity(0.8))
                            .frame(width: geometry.size.width * (item.value / Double(analytics.currentStats.totalProcessings)))
                    }
                    .frame(height: 20)
                    
                    Text("\(Int(item.value))")
                        .font(.caption)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }
    
    // MARK: - Weekly Trends
    
    private var weeklyTrendsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Weekly Trends")
                    .font(.headline)
                Spacer()
            }
            
            let trends = analytics.weeklyTrends
            
            HStack(spacing: 16) {
                trendItem(
                    title: "Total",
                    value: "\(trends.totalProcessings)",
                    trend: trends.totalProcessings > 0 ? .up : .flat,
                    color: .blue
                )
                
                trendItem(
                    title: "On-Device",
                    value: "\(Int(trends.onDeviceRatio * 100))%",
                    trend: trends.onDeviceRatio > 0.5 ? .up : .down,
                    color: .green
                )
                
                trendItem(
                    title: "Success Rate",
                    value: "\(Int(trends.successRate * 100))%",
                    trend: trends.successRate > 0.9 ? .up : trends.successRate > 0.7 ? .flat : .down,
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func trendItem(title: String, value: String, trend: TrendDirection, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Image(systemName: trend.iconName)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Cost Savings
    
    private var costSavingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Cost Savings")
                    .font(.headline)
                Spacer()
            }
            
            let savings = analytics.costSavings
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Monthly Savings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", savings.monthlySavings))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Total Cost")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", savings.totalMonthlyCost))")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Savings Rate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(savings.savingsPercentage))%")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                VStack {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: savings.savingsPercentage / 100)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(savings.savingsPercentage))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Performance Metrics
    
    private var performanceMetricsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Performance Metrics")
                    .font(.headline)
                Spacer()
            }
            
            let metrics = analytics.getPerformanceMetrics()
            
            VStack(spacing: 12) {
                performanceRow(
                    title: "On-Device",
                    time: "\(String(format: "%.2f", metrics.onDevicePerformance.averageProcessingTime))s",
                    confidence: "\(Int(metrics.onDevicePerformance.averageConfidence * 100))%",
                    success: "\(Int(metrics.onDevicePerformance.successRate * 100))%",
                    color: .green
                )
                
                performanceRow(
                    title: "Server",
                    time: "\(String(format: "%.2f", metrics.serverPerformance.averageProcessingTime))s",
                    confidence: "\(Int(metrics.serverPerformance.averageConfidence * 100))%",
                    success: "\(Int(metrics.serverPerformance.successRate * 100))%",
                    color: .blue
                )
                
                performanceRow(
                    title: "Hybrid",
                    time: "\(String(format: "%.2f", metrics.hybridPerformance.averageProcessingTime))s",
                    confidence: "\(Int(metrics.hybridPerformance.averageConfidence * 100))%",
                    success: "\(Int(metrics.hybridPerformance.successRate * 100))%",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func performanceRow(title: String, time: String, confidence: String, success: String, color: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.subheadline)
                    .frame(width: 80, alignment: .leading)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(time)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text("Time")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 50)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(confidence)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text("Confidence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(success)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text("Success")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
        }
    }
    
    // MARK: - Settings Section
    
    private var settingsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Processing Settings")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                NavigationLink("Processing Preferences") {
                    ProcessingPreferencesView()
                }
                .foregroundColor(.primary)
                
                NavigationLink("Privacy Settings") {
                    PrivacySettingsView()
                }
                .foregroundColor(.primary)
                
                NavigationLink("Performance Tuning") {
                    PerformanceTuningView()
                }
                .foregroundColor(.primary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Helper Methods
    
    private func exportAnalyticsData() {
        exportData = analytics.exportAnalyticsData()
        showingExportSheet = true
    }
}

// MARK: - Supporting Types

private struct ChartData {
    let category: String
    let value: Double
    let color: Color
}

private enum TrendDirection {
    case up, down, flat
    
    var iconName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .flat: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .flat: return .gray
        }
    }
}

// MARK: - Placeholder Views (to be implemented)

private struct DetailedAnalyticsView: View {
    var body: some View {
        Text("Detailed Analytics View")
            .navigationTitle("Detailed Analytics")
    }
}

private struct ProcessingPreferencesView: View {
    var body: some View {
        Text("Processing Preferences")
            .navigationTitle("Preferences")
    }
}

private struct PrivacySettingsView: View {
    var body: some View {
        Text("Privacy Settings")
            .navigationTitle("Privacy")
    }
}

private struct PerformanceTuningView: View {
    var body: some View {
        Text("Performance Tuning")
            .navigationTitle("Performance")
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct HybridProcessingStatusView_Previews: PreviewProvider {
    static var previews: some View {
        HybridProcessingStatusView()
    }
}