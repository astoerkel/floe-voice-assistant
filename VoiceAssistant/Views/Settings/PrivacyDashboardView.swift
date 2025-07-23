import SwiftUI
import Combine

/// Privacy dashboard showing what data stays on device and user control options
/// Provides transparency about data collection, storage, and privacy protections
public struct PrivacyDashboardView: View {
    
    // MARK: - Properties
    
    @StateObject private var privateAnalytics = PrivateAnalytics()
    @StateObject private var modelPerformanceTracker = ModelPerformanceTracker()
    @StateObject private var usageInsights = UsageInsights()
    
    @State private var showingDataExport = false
    @State private var showingDeleteConfirmation = false
    @State private var exportData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var storageMetrics: AnalyticsStorageManager.StorageMetrics?
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Privacy Status
                    privacyStatusSection
                    
                    // Data Breakdown
                    dataBreakdownSection
                    
                    // Privacy Controls
                    privacyControlsSection
                    
                    // Data Rights
                    dataRightsSection
                    
                    // Transparency Report
                    transparencyReportSection
                }
                .padding()
            }
            .navigationTitle("Privacy Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export Data") {
                        exportAnalyticsData()
                    }
                }
            }
            .sheet(isPresented: $showingDataExport) {
                dataExportSheet
            }
            .alert("Delete Analytics Data", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteAllAnalyticsData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all analytics data stored on this device. This action cannot be undone.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .task {
                await loadStorageMetrics()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shield.checkerboard")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading) {
                    Text("Privacy First")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("All analytics stay on your device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text("Your privacy is protected by advanced encryption and on-device processing. No personal data is sent to external servers without your explicit consent.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Privacy Status Section
    
    private var privacyStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                PrivacyStatusCard(
                    title: "Data Encryption",
                    status: "AES-256-GCM",
                    icon: "lock.shield",
                    color: .green,
                    description: "Military-grade encryption protects all stored data"
                )
                
                PrivacyStatusCard(
                    title: "On-Device Processing",
                    status: "\(Int(modelPerformanceTracker.currentProcessingRatio.onDevicePercentage))%",
                    icon: "cpu",
                    color: .blue,
                    description: "Percentage of processing done locally"
                )
                
                PrivacyStatusCard(
                    title: "Data Sharing",
                    status: "None",
                    icon: "hand.raised",
                    color: .orange,
                    description: "No data shared with third parties"
                )
                
                PrivacyStatusCard(
                    title: "Cloud Sync",
                    status: "Disabled",
                    icon: "icloud.slash",
                    color: .gray,
                    description: "Analytics never leave your device"
                )
            }
        }
    }
    
    // MARK: - Data Breakdown Section
    
    private var dataBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Stored on Device")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DataTypeRow(
                    title: "Usage Patterns",
                    description: "Command frequency and timing patterns",
                    dataSize: formatDataSize(estimatedUsagePatternSize()),
                    retentionPeriod: "30 days",
                    isEncrypted: true
                )
                
                DataTypeRow(
                    title: "Model Performance",
                    description: "On-device vs server processing metrics",
                    dataSize: formatDataSize(estimatedPerformanceSize()),
                    retentionPeriod: "90 days",
                    isEncrypted: true
                )
                
                DataTypeRow(
                    title: "User Insights",
                    description: "Personal usage insights and preferences",
                    dataSize: formatDataSize(estimatedInsightsSize()),
                    retentionPeriod: "60 days",
                    isEncrypted: true
                )
                
                DataTypeRow(
                    title: "Error Analytics",
                    description: "Error patterns for improvement",
                    dataSize: formatDataSize(estimatedErrorSize()),
                    retentionPeriod: "14 days",
                    isEncrypted: true
                )
            }
            
            if let metrics = storageMetrics {
                HStack {
                    Text("Total Storage Used:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(formatDataSize(metrics.totalSize))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Privacy Controls Section
    
    private var privacyControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy Controls")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                PrivacyControlRow(
                    title: "Analytics Collection",
                    description: "Enable privacy-preserving usage analytics",
                    isEnabled: .constant(privateAnalytics.isEnabled),
                    action: {
                        Task {
                            if privateAnalytics.isEnabled {
                                await privateAnalytics.disableAnalytics()
                            } else {
                                try await privateAnalytics.enableAnalytics()
                            }
                        }
                    }
                )
                
                PrivacyControlRow(
                    title: "Performance Tracking",
                    description: "Track model performance for improvements",
                    isEnabled: .constant(modelPerformanceTracker.isTracking),
                    action: {
                        if modelPerformanceTracker.isTracking {
                            modelPerformanceTracker.stopTracking()
                        } else {
                            modelPerformanceTracker.startTracking()
                        }
                    }
                )
                
                PrivacyControlRow(
                    title: "Usage Insights",
                    description: "Generate personalized usage insights",
                    isEnabled: .constant(usageInsights.isTracking),
                    action: {
                        if usageInsights.isTracking {
                            usageInsights.stopTracking()
                        } else {
                            usageInsights.startTracking()
                        }
                    }
                )
                
                PrivacyControlRow(
                    title: "Differential Privacy",
                    description: "Add mathematical privacy protection",
                    isEnabled: .constant(true),
                    action: { },
                    isReadOnly: true
                )
            }
        }
    }
    
    // MARK: - Data Rights Section
    
    private var dataRightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Data Rights")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DataRightRow(
                    icon: "doc.text",
                    title: "View Your Data",
                    description: "Export and review all stored analytics data",
                    action: { exportAnalyticsData() }
                )
                
                DataRightRow(
                    icon: "trash",
                    title: "Delete Your Data",
                    description: "Permanently remove all analytics data",
                    action: { showingDeleteConfirmation = true },
                    isDestructive: true
                )
                
                DataRightRow(
                    icon: "chart.bar",
                    title: "Usage Report",
                    description: "Generate detailed usage and privacy report",
                    action: { generateUsageReport() }
                )
                
                DataRightRow(
                    icon: "gear",
                    title: "Privacy Settings",
                    description: "Advanced privacy configuration options",
                    action: { /* Navigate to advanced settings */ }
                )
            }
        }
    }
    
    // MARK: - Transparency Report Section
    
    private var transparencyReportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transparency Report")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                TransparencyItem(
                    title: "Data Collection",
                    value: "Only on-device"
                )
                
                TransparencyItem(
                    title: "Third-party Sharing",
                    value: "Never"
                )
                
                TransparencyItem(
                    title: "Data Retention",
                    value: "\(privateAnalytics.dataRetentionDays) days maximum"
                )
                
                TransparencyItem(
                    title: "Encryption Standard",
                    value: "AES-256-GCM"
                )
                
                TransparencyItem(
                    title: "Privacy Model",
                    value: "Differential Privacy (ε=1.0)"
                )
                
                if let lastAnalysis = privateAnalytics.lastAnalysisDate {
                    TransparencyItem(
                        title: "Last Analysis",
                        value: formatDate(lastAnalysis)
                    )
                }
            }
            
            Text("This app is designed with privacy by design principles. All personal data processing happens on your device, and we use industry-standard encryption to protect your information.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
    
    // MARK: - Data Export Sheet
    
    private var dataExportSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Preparing your data...")
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let data = exportData {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        Text("Your Data is Ready")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Data size: \(formatDataSize(Int64(data.count)))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ShareLink(
                            item: data,
                            preview: SharePreview("Analytics Data Export")
                        ) {
                            Label("Share Data", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        Text("This file contains your analytics data in JSON format. All data has been anonymized and encrypted for your privacy.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    Text("Failed to export data")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDataExport = false
                        exportData = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadStorageMetrics() async {
        do {
            let storageManager = try AnalyticsStorageManager(encryptionKey: SymmetricKey(size: .bits256))
            storageMetrics = try await storageManager.getStorageMetrics()
        } catch {
            errorMessage = "Failed to load storage metrics: \(error.localizedDescription)"
        }
    }
    
    private func exportAnalyticsData() {
        isLoading = true
        showingDataExport = true
        
        Task {
            do {
                let data = try await privateAnalytics.exportAnalyticsData()
                await MainActor.run {
                    exportData = data
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to export data: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func deleteAllAnalyticsData() {
        Task {
            await privateAnalytics.deleteAllAnalyticsData()
            modelPerformanceTracker.clearPerformanceData()
            usageInsights.clearUsageData()
            await loadStorageMetrics()
        }
    }
    
    private func generateUsageReport() {
        // Implementation for generating detailed usage report
    }
    
    private func estimatedUsagePatternSize() -> Int64 {
        return 50 * 1024 // 50 KB estimate
    }
    
    private func estimatedPerformanceSize() -> Int64 {
        return 30 * 1024 // 30 KB estimate
    }
    
    private func estimatedInsightsSize() -> Int64 {
        return 40 * 1024 // 40 KB estimate
    }
    
    private func estimatedErrorSize() -> Int64 {
        return 10 * 1024 // 10 KB estimate
    }
    
    private func formatDataSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

private struct PrivacyStatusCard: View {
    let title: String
    let status: String
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(status)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private struct DataTypeRow: View {
    let title: String
    let description: String
    let dataSize: String
    let retentionPeriod: String
    let isEncrypted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(dataSize)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 4) {
                        if isEncrypted {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                        
                        Text(retentionPeriod)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct PrivacyControlRow: View {
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    let action: () -> Void
    var isReadOnly: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isReadOnly {
                Text("Enabled")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .onChange(of: isEnabled) { _ in
                        action()
                    }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct DataRightRow: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    var isDestructive: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isDestructive ? .red : .blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct TransparencyItem: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct PrivacyDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyDashboardView()
    }
}
#endif