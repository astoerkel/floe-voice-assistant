import SwiftUI

/// Settings view for Core ML model management and updates
struct ModelManagementView: View {
    @StateObject private var updateManager: ModelUpdateManager
    @StateObject private var versionControl: ModelVersionControl
    @StateObject private var safetyManager: ModelUpdateSafetyManager
    @State private var showUpdateDetails = false
    @State private var showPerformanceDetails = false
    @State private var showRollbackConfirmation = false
    @State private var showAutomaticUpdatesSheet = false
    
    // Settings
    @AppStorage("automaticUpdatesEnabled") private var automaticUpdatesEnabled = true
    @AppStorage("updateOnlyOnWiFi") private var updateOnlyOnWiFi = true
    @AppStorage("updateOnlyWhileCharging") private var updateOnlyWhileCharging = true
    @AppStorage("enablePerformanceMonitoring") private var enablePerformanceMonitoring = true
    
    init() {
        let versionControl = ModelVersionControl()
        let updateManager = ModelUpdateManager(
            updateServerURL: URL(string: "https://api.voiceassistant.com/models")!,
            versionControl: versionControl
        )
        let safetyManager = ModelUpdateSafetyManager(
            versionControl: versionControl,
            updateManager: updateManager
        )
        
        self._updateManager = StateObject(wrappedValue: updateManager)
        self._versionControl = StateObject(wrappedValue: versionControl)
        self._safetyManager = StateObject(wrappedValue: safetyManager)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Current Model Section
                Section {
                    currentModelCard
                } header: {
                    Text("Current Model")
                }
                
                // Update Status Section
                Section {
                    updateStatusCard
                    
                    if updateManager.isUpdateAvailable {
                        updateAvailableCard
                    }
                } header: {
                    Text("Updates")
                }
                
                // Performance Section
                Section {
                    performanceCard
                    
                    if enablePerformanceMonitoring {
                        performanceTrendCard
                    }
                } header: {
                    Text("Performance")
                }
                
                // Version History Section
                Section {
                    ForEach(Array(versionControl.versionHistory.prefix(5)), id: \.version) { version in
                        versionHistoryRow(version: version)
                    }
                    
                    if versionControl.versionHistory.count > 5 {
                        NavigationLink("View All Versions") {
                            VersionHistoryView(versionControl: versionControl)
                        }
                    }
                } header: {
                    Text("Version History")
                }
                
                // Settings Section  
                Section {
                    settingsToggles
                } header: {
                    Text("Settings")
                }
                
                // Advanced Section
                Section {
                    advancedActions
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Use advanced actions with caution. Manual rollbacks may affect model performance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Model Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Check Updates") {
                        Task {
                            await updateManager.checkForUpdates()
                        }
                    }
                    .disabled(updateManager.updateStatus == .checking)
                }
            }
            .sheet(isPresented: $showUpdateDetails) {
                UpdateDetailsView(
                    updateManager: updateManager,
                    versionControl: versionControl
                )
            }
            .sheet(isPresented: $showPerformanceDetails) {
                PerformanceDetailsView(modelName: versionControl.currentVersion ?? "Unknown")
            }
            .sheet(isPresented: $showAutomaticUpdatesSheet) {
                AutomaticUpdatesSettingsView(safetyManager: safetyManager)
            }
            .alert("Confirm Rollback", isPresented: $showRollbackConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Rollback", role: .destructive) {
                    Task {
                        _ = await updateManager.rollbackToPreviousVersion()
                    }
                }
            } message: {
                Text("Are you sure you want to rollback to the previous model version? This may affect performance.")
            }
        }
        .task {
            await updateManager.checkForUpdates()
        }
    }
    
    // MARK: - Current Model Card
    
    private var currentModelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Version \(updateManager.currentVersion ?? "Unknown")")
                        .font(.headline)
                    
                    if let lastUpdate = versionControl.versionHistory.first?.installDate {
                        Text("Updated \(lastUpdate, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            if let currentVersion = updateManager.currentVersion,
               let metrics = versionControl.performanceMetrics[currentVersion] {
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Accuracy", systemImage: "target")
                        Spacer()
                        Text(String(format: "%.1f%%", metrics.accuracy * 100))
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Label("Avg. Response", systemImage: "timer")
                        Spacer()
                        Text(String(format: "%.0fms", metrics.inferenceTime * 1000))
                            .fontWeight(.semibold)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Update Status Card
    
    private var updateStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Update Status", systemImage: statusIcon)
                    .foregroundColor(statusColor)
                
                Spacer()
                
                if updateManager.updateStatus == .checking {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Text(statusDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if case .downloading = updateManager.updateStatus {
                ProgressView(value: updateManager.downloadProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text(String(format: "%.0f%% complete", updateManager.downloadProgress * 100))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let lastCheck = updateManager.lastUpdateCheck {
                Text("Last checked: \(lastCheck, format: .relative(presentation: .named))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Update Available Card
    
    private var updateAvailableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Update Available")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    if let availableVersion = updateManager.availableVersion {
                        Text("Version \(availableVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            HStack(spacing: 12) {
                Button("View Details") {
                    showUpdateDetails = true
                }
                .buttonStyle(.bordered)
                
                Button("Install Now") {
                    Task {
                        await updateManager.startUpdate(strategy: .immediate)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(updateManager.updateStatus != .idle)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Performance Card
    
    private var performanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Performance", systemImage: "chart.line.uptrend.xyaxis")
                
                Spacer()
                
                Button("Details") {
                    showPerformanceDetails = true
                }
                .font(.caption)
            }
            
            if let currentVersion = updateManager.currentVersion,
               let metrics = versionControl.performanceMetrics[currentVersion] {
                
                HStack {
                    performanceMetricView(
                        title: "Success Rate",
                        value: String(format: "%.1f%%", metrics.successRate * 100),
                        isGood: metrics.successRate > 0.95
                    )
                    
                    Divider()
                    
                    performanceMetricView(
                        title: "Error Rate",
                        value: String(format: "%.1f%%", metrics.errorRate * 100),
                        isGood: metrics.errorRate < 0.05
                    )
                    
                    Divider()
                    
                    performanceMetricView(
                        title: "Battery Impact",
                        value: batteryImpactDescription(metrics.batteryImpact),
                        isGood: metrics.batteryImpact < 0.3
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Performance Trend Card
    
    private var performanceTrendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Trend")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 16) {
                trendIndicator(
                    title: "Accuracy",
                    trend: getTrend(for: "accuracy"),
                    format: "%.1f%%"
                )
                
                trendIndicator(
                    title: "Speed",
                    trend: getTrend(for: "inferenceTime", inverted: true),
                    format: "%.0fms"
                )
                
                trendIndicator(
                    title: "Memory",
                    trend: getTrend(for: "memoryUsage", inverted: true),
                    format: "MB"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Settings Toggles
    
    private var settingsToggles: some View {
        Group {
            Toggle("Automatic Updates", isOn: $automaticUpdatesEnabled)
            
            if automaticUpdatesEnabled {
                Toggle("Wi-Fi Only", isOn: $updateOnlyOnWiFi)
                    .disabled(!automaticUpdatesEnabled)
                
                Toggle("While Charging", isOn: $updateOnlyWhileCharging)
                    .disabled(!automaticUpdatesEnabled)
            }
            
            Toggle("Performance Monitoring", isOn: $enablePerformanceMonitoring)
            
            Button("Configure Automatic Updates") {
                showAutomaticUpdatesSheet = true
            }
        }
    }
    
    // MARK: - Advanced Actions
    
    private var advancedActions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button("Force Update Check") {
                Task {
                    await updateManager.forceUpdate()
                }
            }
            .disabled(updateManager.updateStatus != .idle)
            
            Button("Rollback to Previous Version") {
                showRollbackConfirmation = true
            }
            .foregroundColor(.orange)
            .disabled(versionControl.getPreviousVersion() == nil)
            
            Button("Cancel Current Update") {
                updateManager.cancelUpdate()
            }
            .foregroundColor(.red)
            .disabled({
                switch updateManager.updateStatus {
                case .downloading, .validating, .installing:
                    return false
                default:
                    return true
                }
            }())
        }
    }
    
    // MARK: - Helper Views
    
    private func versionHistoryRow(version: ModelVersionControl.ModelVersion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("v\(version.version)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if version.isActive {
                        Text("ACTIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                }
                
                Text(version.installDate, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if version.rollbackCount > 0 {
                    Text("\(version.rollbackCount) rollback(s)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            if let metrics = versionControl.performanceMetrics[version.version] {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(metrics.accuracy * 100, specifier: "%.1f")%")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("accuracy")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func performanceMetricView(title: String, value: String, isGood: Bool) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isGood ? .green : .orange)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func trendIndicator(title: String, trend: [Double], format: String, inverted: Bool = false) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                let isImproving = trend.count >= 2 && (inverted ? trend.last! < trend.first! : trend.last! > trend.first!)
                
                Image(systemName: isImproving ? "arrow.up" : "arrow.down")
                    .font(.caption2)
                    .foregroundColor(isImproving ? .green : .red)
                
                if let lastValue = trend.last {
                    Text(formatTrendValue(lastValue, format: format))
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Properties & Methods
    
    private var statusIcon: String {
        switch updateManager.updateStatus {
        case .idle:
            return "checkmark.circle"
        case .checking:
            return "magnifyingglass"
        case .downloading:
            return "arrow.down.circle"
        case .validating:
            return "checkmark.shield"
        case .installing:
            return "gear"
        case .completed:
            return "checkmark.circle.fill"
        case .failed(_):
            return "exclamationmark.triangle"
        case .rollback:
            return "arrow.counterclockwise"
        }
    }
    
    private var statusColor: Color {
        switch updateManager.updateStatus {
        case .idle, .completed:
            return .green
        case .checking, .downloading, .validating, .installing, .rollback:
            return .blue
        case .failed(_):
            return .red
        }
    }
    
    private var statusDescription: String {
        switch updateManager.updateStatus {
        case .idle:
            return updateManager.isUpdateAvailable ? "Update available" : "Up to date"
        case .checking:
            return "Checking for updates..."
        case .downloading:
            return "Downloading update..."
        case .validating:
            return "Validating download..."
        case .installing:
            return "Installing update..."
        case .completed:
            return "Update completed successfully"
        case .failed(let error):
            return "Update failed: \(error.localizedDescription)"
        case .rollback:
            return "Rolling back to previous version..."
        }
    }
    
    private func batteryImpactDescription(_ impact: Double) -> String {
        switch impact {
        case 0..<0.2:
            return "Low"
        case 0.2..<0.5:
            return "Medium"
        default:
            return "High"
        }
    }
    
    private func getTrend(for metric: String, inverted: Bool = false) -> [Double] {
        return versionControl.getPerformanceTrend(metric: metric, versions: 3)
    }
    
    private func formatTrendValue(_ value: Double, format: String) -> String {
        switch format {
        case "%.1f%%":
            return String(format: "%.1f%%", value * 100)
        case "%.0fms":
            return String(format: "%.0fms", value * 1000)
        case "MB":
            return String(format: "%.0fMB", value / (1024 * 1024))
        default:
            return String(format: format, value)
        }
    }
}

// MARK: - Stub Views (Temporarily disabled features)

struct VersionHistoryView: View {
    let versionControl: ModelVersionControl
    
    var body: some View {
        Text("Version History (Coming Soon)")
            .font(.headline)
            .foregroundColor(.secondary)
            .padding()
    }
}

struct PerformanceDetailsView: View {
    let modelName: String
    
    var body: some View {
        Text("Performance Details (Coming Soon)")
            .font(.headline)
            .foregroundColor(.secondary)
            .padding()
    }
}

struct AutomaticUpdatesSettingsView: View {
    @ObservedObject var safetyManager: ModelUpdateSafetyManager
    
    var body: some View {
        Text("Automatic Updates Settings (Coming Soon)")
            .font(.headline)
            .foregroundColor(.secondary)
            .padding()
    }
}

// MARK: - Preview

struct ModelManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ModelManagementView()
    }
}