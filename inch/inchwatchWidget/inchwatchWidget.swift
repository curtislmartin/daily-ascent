import WidgetKit
import SwiftUI

// MARK: - Entry

struct InchwatchEntry: TimelineEntry {
    let date: Date
    let dueCount: Int
    let completedToday: Int
    let nextExerciseName: String?

    var totalToday: Int { dueCount + completedToday }
    var isRestDay: Bool { totalToday == 0 }
    var isAllDone: Bool { totalToday > 0 && dueCount == 0 }

    static func fromDefaults() -> InchwatchEntry {
        let dueCount = UserDefaults.standard.integer(forKey: "watch.complication.dueCount")
        let completedToday = UserDefaults.standard.integer(forKey: "watch.complication.completedToday")
        let nextExerciseName = UserDefaults.standard.string(forKey: "watch.complication.nextExerciseName")
        return InchwatchEntry(
            date: .now,
            dueCount: dueCount,
            completedToday: completedToday,
            nextExerciseName: nextExerciseName
        )
    }

    static var placeholder: InchwatchEntry {
        InchwatchEntry(date: .now, dueCount: 3, completedToday: 0, nextExerciseName: "Push-Ups")
    }
}

// MARK: - Provider

struct InchwatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> InchwatchEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (InchwatchEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .fromDefaults())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InchwatchEntry>) -> Void) {
        let entry = InchwatchEntry.fromDefaults()
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Views

struct inchwatchWidgetEntryView: View {
    var entry: InchwatchEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryRectangular:
            rectangularView
        default:
            inlineView
        }
    }

    // MARK: Circular

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.isRestDay {
                VStack(spacing: 1) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 11))
                    Text("Rest")
                        .font(.system(size: 10, weight: .medium))
                }
            } else if entry.isAllDone {
                VStack(spacing: 1) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                    Text("Done")
                        .font(.system(size: 10, weight: .medium))
                }
            } else {
                VStack(spacing: 0) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 10))
                    Text("\(entry.dueCount)")
                        .font(.system(size: 20, weight: .bold))
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    // MARK: Corner

    private var cornerView: some View {
        if entry.isRestDay {
            return Text("Rest day")
                .widgetLabel("DAILY ASCENT")
        } else if entry.isAllDone {
            return Text("Done")
                .widgetLabel("DAILY ASCENT")
        } else {
            return Text("\(entry.dueCount) left")
                .widgetLabel("DAILY ASCENT")
        }
    }

    // MARK: Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Daily Ascent")
                .font(.headline)
                .foregroundStyle(.primary)
            if entry.isRestDay {
                Label("Rest day", systemImage: "moon.zzz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if entry.isAllDone {
                Label("All done today", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Label(
                    "\(entry.dueCount) of \(entry.totalToday) remaining",
                    systemImage: "figure.strengthtraining.traditional"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                if let next = entry.nextExerciseName {
                    Text("Next: \(next)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Inline

    private var inlineView: some View {
        if entry.isRestDay {
            return Text("Rest day")
        } else if entry.isAllDone {
            return Text("All done")
        } else {
            return Text("\(entry.dueCount) exercise\(entry.dueCount == 1 ? "" : "s") left")
        }
    }
}

// MARK: - Widget

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
