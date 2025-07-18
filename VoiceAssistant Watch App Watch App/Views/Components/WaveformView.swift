import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    let state: VoiceState
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<15, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(barColor)
                    .frame(width: 2, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: levels)
            }
        }
        .frame(height: 25)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        switch state {
        case .idle:
            return 2
        case .listening:
            if index < levels.count {
                return max(2, CGFloat(levels[index]) * 20)
            } else {
                return 2
            }
        case .processing:
            let normalizedIndex = CGFloat(index) / 15.0
            let waveHeight = sin(normalizedIndex * .pi * 4 + Date().timeIntervalSince1970 * 8) * 8 + 12
            return max(2, waveHeight)
        case .responding:
            let normalizedIndex = CGFloat(index) / 15.0
            let waveHeight = sin(normalizedIndex * .pi * 2 + Date().timeIntervalSince1970 * 6) * 6 + 10
            return max(2, waveHeight)
        case .error:
            return 2
        }
    }
    
    private var barColor: Color {
        switch state {
        case .idle:
            return .gray.opacity(0.3)
        case .listening:
            return .blue
        case .processing:
            return .orange
        case .responding:
            return .green
        case .error:
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformView(levels: [0.2, 0.5, 0.8, 0.3, 0.6], state: .idle)
        WaveformView(levels: [0.2, 0.5, 0.8, 0.3, 0.6], state: .listening)
        WaveformView(levels: [0.2, 0.5, 0.8, 0.3, 0.6], state: .processing)
        WaveformView(levels: [0.2, 0.5, 0.8, 0.3, 0.6], state: .responding)
        WaveformView(levels: [0.2, 0.5, 0.8, 0.3, 0.6], state: .error)
    }
    .padding()
}