import SwiftUI

struct SpeechConfidenceIndicator: View {
    let confidence: Float
    let processingMode: EnhancedSpeechRecognizer.ProcessingMode
    let enhancements: [String]
    let isVisible: Bool
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.9...1.0:
            return .green
        case 0.75..<0.9:
            return .blue
        case 0.5..<0.75:
            return .orange
        default:
            return .red
        }
    }
    
    private var confidenceText: String {
        switch confidence {
        case 0.9...1.0:
            return "Excellent"
        case 0.75..<0.9:
            return "Good"
        case 0.5..<0.75:
            return "Fair"
        default:
            return "Poor"
        }
    }
    
    private var processingModeIcon: String {
        switch processingMode {
        case .onDevice:
            return "iphone"
        case .server:
            return "cloud"
        case .hybrid:
            return "arrow.triangle.2.circlepath"
        case .enhanced:
            return "brain.head.profile"
        }
    }
    
    var body: some View {
        if isVisible {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // Processing mode indicator
                    HStack(spacing: 4) {
                        Image(systemName: processingModeIcon)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text(processingMode.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Confidence indicator
                    HStack(spacing: 6) {
                        confidenceBar
                        
                        Text(confidenceText)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(confidenceColor)
                    }
                }
                
                // Enhancement indicators
                if !enhancements.isEmpty {
                    enhancementIndicators
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                    .backdrop(blur: 10)
            )
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }
    
    private var confidenceBar: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: confidence)
            }
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let threshold = Float(index + 1) * 0.2
        return confidence >= threshold ? confidenceColor : Color.gray.opacity(0.3)
    }
    
    private var enhancementIndicators: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(enhancements, id: \.self) { enhancement in
                    enhancementBadge(enhancement)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func enhancementBadge(_ enhancement: String) -> some View {
        HStack(spacing: 3) {
            enhancementIcon(enhancement)
            
            Text(enhancementAbbreviation(enhancement))
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private func enhancementIcon(_ enhancement: String) -> some View {
        Image(systemName: enhancementSystemName(enhancement))
            .font(.system(size: 8))
    }
    
    private func enhancementSystemName(_ enhancement: String) -> String {
        switch enhancement {
        case "Noise Reduction":
            return "waveform.path.badge.minus"
        case "Vocabulary Boost":
            return "text.book.closed"
        case "Accent Adaptation":
            return "person.wave.2"
        case "Pattern Learning":
            return "brain"
        case "Context Aware":
            return "lightbulb"
        default:
            return "checkmark.circle.fill"
        }
    }
    
    private func enhancementAbbreviation(_ enhancement: String) -> String {
        switch enhancement {
        case "Noise Reduction":
            return "NR"
        case "Vocabulary Boost":
            return "VB"
        case "Accent Adaptation":
            return "AA"
        case "Pattern Learning":
            return "PL"
        case "Context Aware":
            return "CA"
        default:
            return "EN"
        }
    }
}

// MARK: - Backdrop Modifier

struct BackdropBlurView: UIViewRepresentable {
    let radius: CGFloat
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let effect = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: effect)
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // No updates needed
    }
}

extension View {
    func backdrop(blur radius: CGFloat) -> some View {
        self.overlay(
            BackdropBlurView(radius: radius)
                .allowsHitTesting(false)
        )
    }
}

// MARK: - Preview

struct SpeechConfidenceIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // High confidence with enhancements
            SpeechConfidenceIndicator(
                confidence: 0.95,
                processingMode: .enhanced,
                enhancements: ["Noise Reduction", "Vocabulary Boost", "Pattern Learning"],
                isVisible: true
            )
            
            // Medium confidence hybrid
            SpeechConfidenceIndicator(
                confidence: 0.75,
                processingMode: .hybrid,
                enhancements: ["Vocabulary Boost"],
                isVisible: true
            )
            
            // Low confidence on-device
            SpeechConfidenceIndicator(
                confidence: 0.45,
                processingMode: .onDevice,
                enhancements: [],
                isVisible: true
            )
            
            // Server processing
            SpeechConfidenceIndicator(
                confidence: 0.85,
                processingMode: .server,
                enhancements: ["Context Aware"],
                isVisible: true
            )
        }
        .padding()
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}