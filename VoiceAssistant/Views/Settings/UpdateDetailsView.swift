import SwiftUI

/// Detailed view for model update information and installation
struct UpdateDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var updateManager: ModelUpdateManager
    @ObservedObject var versionControl: ModelVersionControl
    
    @State private var selectedUpdateStrategy: ModelUpdateManager.UpdateStrategy = .optimal
    @State private var showInstallConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Update Header
                    updateHeaderSection
                    
                    // Changelog Section
                    if let availableVersion = updateManager.availableVersion,
                       let versionInfo = versionControl.versionHistory.first(where: { $0.version == availableVersion }) {
                        changelogSection(versionInfo: versionInfo)
                    }
                    
                    // Performance Impact Section
                    performanceImpactSection
                    
                    // Update Strategy Section
                    updateStrategySection
                    
                    // Compatibility Section
                    compatibilitySection
                    
                    // Installation Options
                    installationSection
                }
                .padding()
            }
            .navigationTitle("Update Details")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Install Update", isPresented: $showInstallConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Install") {
                    Task {
                        await updateManager.startUpdate(strategy: selectedUpdateStrategy)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to install this update? The installation will happen in the background.")
            }
        }
    }
    
    // MARK: - Update Header Section
    
    private var updateHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model Update Available")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let availableVersion = updateManager.availableVersion {
                        Text("Version \(availableVersion)")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Image(systemName: "brain.head.profile")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
            }
            
            HStack(spacing: 20) {
                updateInfoItem(
                    icon: "arrow.down.circle",
                    title: "Download Size",
                    value: "25.3 MB" // This would come from server
                )
                
                updateInfoItem(
                    icon: "speedometer",
                    title: "Update Type",
                    value: "Performance"
                )
                
                updateInfoItem(
                    icon: "clock",
                    title: "Install Time",
                    value: "~2 minutes"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Changelog Section
    
    private func changelogSection(versionInfo: ModelVersionControl.ModelVersion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What's New", systemImage: "doc.text")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(versionInfo.changelog.enumerated()), id: \.offset) { index, entry in
                    changelogItem(entry: entry)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func changelogItem(entry: ModelVersionControl.ModelVersion.ChangelogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForCategory(entry.category))
                .font(.caption)
                .foregroundColor(colorForCategory(entry.category))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(categoryTitle(entry.category))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(colorForCategory(entry.category))
                    
                    Spacer()
                    
                    impactBadge(entry.impact)
                }
                
                Text(entry.description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Performance Impact Section
    
    private var performanceImpactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Expected Performance Impact", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                performanceImpactRow(
                    metric: "Accuracy",
                    change: "+2.3%",
                    isImprovement: true,
                    description: "Better intent recognition"
                )
                
                performanceImpactRow(
                    metric: "Response Time",
                    change: "-15ms",
                    isImprovement: true,
                    description: "Faster inference"
                )
                
                performanceImpactRow(
                    metric: "Memory Usage",
                    change: "+3MB",
                    isImprovement: false,
                    description: "Slightly higher memory usage"
                )
                
                performanceImpactRow(
                    metric: "Battery Impact",
                    change: "No change",
                    isImprovement: nil,
                    description: "Same power efficiency"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Update Strategy Section
    
    private var updateStrategySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Installation Strategy", systemImage: "gear")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                updateStrategyOption(
                    strategy: .immediate,
                    title: "Install Now",
                    description: "Install immediately",
                    icon: "bolt"
                )
                
                updateStrategyOption(
                    strategy: .optimal,
                    title: "Smart Install",
                    description: "Install when charging and on Wi-Fi",
                    icon: "brain"
                )
                
                updateStrategyOption(
                    strategy: .scheduled(Date().addingTimeInterval(3600)),
                    title: "Schedule for Later",
                    description: "Install in 1 hour",
                    icon: "clock"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Compatibility Section
    
    private var compatibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Compatibility", systemImage: "checkmark.shield")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                compatibilityItem(
                    title: "iOS Version",
                    requirement: "iOS 15.0+",
                    current: "iOS \(UIDevice.current.systemVersion)",
                    isCompatible: true
                )
                
                compatibilityItem(
                    title: "Device",
                    requirement: "iPhone, iPad",
                    current: UIDevice.current.model,
                    isCompatible: true
                )
                
                compatibilityItem(
                    title: "Available Storage",
                    requirement: "50 MB free",
                    current: "2.1 GB available",
                    isCompatible: true
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Installation Section
    
    private var installationSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                showInstallConfirmation = true
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Install Update")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!(updateManager.updateStatus == ModelUpdateManager.UpdateStatus.idle))
            
            if !(updateManager.updateStatus == ModelUpdateManager.UpdateStatus.idle) {
                VStack(spacing: 8) {
                    Text("Installation in progress...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if case .downloading = updateManager.updateStatus {
                        ProgressView(value: updateManager.downloadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
            }
            
            Text("Updates are installed in the background and won't interrupt your use of the app.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Helper Views
    
    private func updateInfoItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func performanceImpactRow(metric: String, change: String, isImprovement: Bool?, description: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(metric)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if let isImprovement = isImprovement {
                    Image(systemName: isImprovement ? "arrow.up" : "arrow.down")
                        .font(.caption)
                        .foregroundColor(isImprovement ? .green : .orange)
                }
                
                Text(change)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(
                        isImprovement == true ? .green :
                        isImprovement == false ? .orange : .secondary
                    )
            }
        }
        .padding(.vertical, 4)
    }
    
    private func updateStrategyOption(strategy: ModelUpdateManager.UpdateStrategy, title: String, description: String, icon: String) -> some View {
        Button(action: {
            selectedUpdateStrategy = strategy
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: selectedUpdateStrategy.description == strategy.description ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedUpdateStrategy.description == strategy.description ? .blue : .secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func compatibilityItem(title: String, requirement: String, current: String, isCompatible: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Requires: \(requirement)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: isCompatible ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isCompatible ? .green : .red)
                
                Text(current)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func impactBadge(_ impact: ModelVersionControl.ModelVersion.ChangelogEntry.ImpactLevel) -> some View {
        Text(impact.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colorForImpact(impact))
            .cornerRadius(4)
    }
    
    // MARK: - Helper Functions
    
    private func iconForCategory(_ category: ModelVersionControl.ModelVersion.ChangelogEntry.ChangeCategory) -> String {
        switch category {
        case .accuracy:
            return "target"
        case .performance:
            return "speedometer"
        case .features:
            return "star"
        case .bugfix:
            return "wrench"
        case .security:
            return "shield"
        case .compatibility:
            return "checkmark.shield"
        }
    }
    
    private func colorForCategory(_ category: ModelVersionControl.ModelVersion.ChangelogEntry.ChangeCategory) -> Color {
        switch category {
        case .accuracy:
            return .green
        case .performance:
            return .blue
        case .features:
            return .purple
        case .bugfix:
            return .orange
        case .security:
            return .red
        case .compatibility:
            return .teal
        }
    }
    
    private func categoryTitle(_ category: ModelVersionControl.ModelVersion.ChangelogEntry.ChangeCategory) -> String {
        switch category {
        case .accuracy:
            return "ACCURACY"
        case .performance:
            return "PERFORMANCE"
        case .features:
            return "FEATURES"
        case .bugfix:
            return "BUG FIX"
        case .security:
            return "SECURITY"
        case .compatibility:
            return "COMPATIBILITY"
        }
    }
    
    private func colorForImpact(_ impact: ModelVersionControl.ModelVersion.ChangelogEntry.ImpactLevel) -> Color {
        switch impact {
        case .major:
            return .red
        case .minor:
            return .orange
        case .patch:
            return .blue
        }
    }
}

// MARK: - Extensions

extension ModelUpdateManager.UpdateStrategy {
    var description: String {
        switch self {
        case .immediate:
            return "immediate"
        case .optimal:
            return "optimal"
        case .gradual(let percentage):
            return "gradual-\(percentage)"
        case .scheduled(let date):
            return "scheduled-\(date.timeIntervalSince1970)"
        }
    }
}

// MARK: - Preview

struct UpdateDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let versionControl = ModelVersionControl()
        let updateManager = ModelUpdateManager(
            updateServerURL: URL(string: "https://api.example.com")!,
            versionControl: versionControl
        )
        
        UpdateDetailsView(
            updateManager: updateManager,
            versionControl: versionControl
        )
    }
}