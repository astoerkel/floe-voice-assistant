import SwiftUI

/// Visual indicator showing where voice processing is happening
public struct ProcessingLocationIndicator: View {
    
    // MARK: - Properties
    let location: ProcessingLocation
    let confidence: Double
    let isProcessing: Bool
    let compact: Bool
    
    // MARK: - Animation State
    @State private var isAnimating = false
    
    public init(
        location: ProcessingLocation,
        confidence: Double = 1.0,
        isProcessing: Bool = false,
        compact: Bool = false
    ) {
        self.location = location
        self.confidence = confidence
        self.isProcessing = isProcessing
        self.compact = compact
    }
    
    public var body: some View {
        if compact {
            compactIndicator
        } else {
            fullIndicator
        }
    }
    
    // MARK: - Compact Indicator
    
    private var compactIndicator: some View {
        HStack(spacing: 4) {
            locationIcon
                .font(.caption2)
                .foregroundColor(locationColor)
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(locationColor.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(locationColor.opacity(0.3), lineWidth: 0.5)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: location)
    }
    
    // MARK: - Full Indicator
    
    private var fullIndicator: some View {
        VStack(spacing: 8) {
            // Main indicator with icon and animation
            HStack(spacing: 12) {
                // Processing location icon with animation
                ZStack {
                    Circle()
                        .fill(locationColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    locationIcon
                        .font(.title2)
                        .foregroundColor(locationColor)
                        .scaleEffect(isProcessing ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatWhileActive(isProcessing), value: isProcessing)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Location title
                    Text(locationTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Status and confidence
                    HStack(spacing: 8) {
                        if isProcessing {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Processing...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // Confidence indicator
                            HStack(spacing: 4) {
                                confidenceIndicator
                                Text("\(Int(confidence * 100))% confidence")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Additional indicators
                VStack(spacing: 4) {
                    privacyIndicator
                    costIndicator
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            
            // Processing details (when processing)
            if isProcessing {
                processingDetails
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isProcessing)
    }
    
    // MARK: - Processing Details
    
    private var processingDetails: some View {
        HStack(spacing: 16) {
            // Processing steps indicator
            HStack(spacing: 8) {
                ForEach(processingSteps, id: \.0) { step, isActive in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(isActive ? locationColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(isActive ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.5), value: isActive)
                        
                        Text(step)
                            .font(.caption2)
                            .foregroundColor(isActive ? .primary : .secondary)
                    }
                }
            }
            
            Spacer()
            
            // Estimated time
            Text("~\(estimatedProcessingTime)s")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Computed Properties
    
    private var locationIcon: some View {
        Group {
            switch location {
            case .onDevice:
                Image(systemName: "iphone")
            case .server:
                Image(systemName: "cloud")
            case .hybrid:
                Image(systemName: "arrow.triangle.2.circlepath")
            case .fallback:
                Image(systemName: "exclamationmark.triangle")
            }
        }
    }
    
    private var locationColor: Color {
        switch location {
        case .onDevice:
            return .green
        case .server:
            return .blue
        case .hybrid:
            return .purple
        case .fallback:
            return .orange
        }
    }
    
    private var locationTitle: String {
        switch location {
        case .onDevice:
            return "On-Device Processing"
        case .server:
            return "Cloud Processing"
        case .hybrid:
            return "Hybrid Processing"
        case .fallback:
            return "Fallback Processing"
        }
    }
    
    private var processingSteps: [(String, Bool)] {
        switch location {
        case .onDevice:
            return [
                ("Analyze", true),
                ("Process", isProcessing),
                ("Generate", false),
                ("Complete", false)
            ]
        case .server:
            return [
                ("Upload", true),
                ("Process", isProcessing),
                ("Download", false),
                ("Complete", false)
            ]
        case .hybrid:
            return [
                ("Local", true),
                ("Cloud", isProcessing),
                ("Merge", false),
                ("Complete", false)
            ]
        case .fallback:
            return [
                ("Retry", true),
                ("Basic", isProcessing),
                ("Complete", false)
            ]
        }
    }
    
    private var estimatedProcessingTime: String {
        switch location {
        case .onDevice:
            return "0.5"
        case .server:
            return "2.0"
        case .hybrid:
            return "1.5"
        case .fallback:
            return "0.2"
        }
    }
    
    private var confidenceIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(Double(index) < confidence * 5 ? locationColor : Color.gray.opacity(0.3))
                    .frame(width: 3, height: 8)
                    .cornerRadius(1)
            }
        }
    }
    
    private var privacyIndicator: some View {
        Image(systemName: location == .onDevice ? "lock.fill" : "lock.open")
            .font(.caption2)
            .foregroundColor(location == .onDevice ? .green : .orange)
    }
    
    private var costIndicator: some View {
        Image(systemName: location == .onDevice ? "dollarsign.circle.fill" : "dollarsign.circle")
            .font(.caption2)
            .foregroundColor(location == .onDevice ? .green : .blue)
    }
}

// MARK: - Animation Extension

extension Animation {
    func repeatWhileActive(_ condition: Bool) -> Animation {
        return condition ? self.repeatForever(autoreverses: true) : self
    }
}

// MARK: - Preview Provider

struct ProcessingLocationIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Compact indicators
            HStack(spacing: 12) {
                ProcessingLocationIndicator(location: .onDevice, compact: true)
                ProcessingLocationIndicator(location: .server, compact: true)
                ProcessingLocationIndicator(location: .hybrid, isProcessing: true, compact: true)
                ProcessingLocationIndicator(location: .fallback, compact: true)
            }
            
            Divider()
            
            // Full indicators
            VStack(spacing: 16) {
                ProcessingLocationIndicator(
                    location: .onDevice,
                    confidence: 0.9,
                    isProcessing: false
                )
                
                ProcessingLocationIndicator(
                    location: .server,
                    confidence: 0.8,
                    isProcessing: true
                )
                
                ProcessingLocationIndicator(
                    location: .hybrid,
                    confidence: 0.95,
                    isProcessing: false,
                    compact: false
                )
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}