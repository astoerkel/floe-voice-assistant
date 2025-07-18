import SwiftUI
import WidgetKit

// NOTE: Complications require a separate Widget Extension target
// This is provided as a reference implementation for future widget extension setup
/*
struct AdaptiveComplication: Widget {
    let kind: String = "adaptive-assistant"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: AdaptiveComplicationProvider()
        ) { entry in
            AdaptiveComplicationView(entry: entry)
        }
        .configurationDisplayName("Smart Assistant")
        .description("Shows relevant info based on time and context")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct AdaptiveComplicationView: View {
    let entry: AdaptiveComplicationEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }
    
    private var circularView: some View {
        ZStack {
            Circle()
                .fill(entry.contextType.color.opacity(0.2))
            
            VStack(spacing: 2) {
                Image(systemName: entry.contextType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(entry.contextType.color)
                
                Text(entry.displayText)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .opacity(entry.urgencyLevel.opacity)
    }
    
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: entry.contextType.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(entry.contextType.color)
                
                Text(entry.displayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(entry.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Text(entry.detailText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .opacity(entry.urgencyLevel.opacity)
    }
    
    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.contextType.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(entry.contextType.color)
            
            Text(entry.displayText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            
            Text("•")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text(entry.detailText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .opacity(entry.urgencyLevel.opacity)
    }
    
    private var cornerView: some View {
        VStack(spacing: 1) {
            Image(systemName: entry.contextType.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(entry.contextType.color)
            
            Text(entry.displayText)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .opacity(entry.urgencyLevel.opacity)
    }
}
*/

/*
#Preview("Circular", as: .accessoryCircular) {
    AdaptiveComplication()
} timeline: {
    AdaptiveComplicationEntry(
        date: Date(),
        contextType: .morning,
        displayText: "Morning",
        detailText: "Next meeting",
        urgencyLevel: .high
    )
}

#Preview("Rectangular", as: .accessoryRectangular) {
    AdaptiveComplication()
} timeline: {
    AdaptiveComplicationEntry(
        date: Date(),
        contextType: .workMorning,
        displayText: "Work",
        detailText: "3 tasks",
        urgencyLevel: .medium
    )
}

#Preview("Inline", as: .accessoryInline) {
    AdaptiveComplication()
} timeline: {
    AdaptiveComplicationEntry(
        date: Date(),
        contextType: .evening,
        displayText: "Evening",
        detailText: "Tomorrow's first",
        urgencyLevel: .low
    )
}

#Preview("Corner", as: .accessoryCorner) {
    AdaptiveComplication()
} timeline: {
    AdaptiveComplicationEntry(
        date: Date(),
        contextType: .general,
        displayText: "Voice",
        detailText: "Tap to speak",
        urgencyLevel: .normal
    )
}
*/