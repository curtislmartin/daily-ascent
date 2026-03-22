import WidgetKit
import SwiftUI

struct InchwatchPlaceholderEntry: TimelineEntry {
    let date: Date
}

struct InchwatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> InchwatchPlaceholderEntry {
        InchwatchPlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (InchwatchPlaceholderEntry) -> Void) {
        completion(InchwatchPlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InchwatchPlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [InchwatchPlaceholderEntry(date: .now)], policy: .never))
    }
}

struct inchwatchWidgetEntryView: View {
    var entry: InchwatchPlaceholderEntry

    var body: some View {
        Text("Daily Ascent")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct inchwatchWidget: Widget {
    let kind: String = "inchwatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: InchwatchProvider()) { entry in
            inchwatchWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Ascent")
        .description("Today's training status.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
