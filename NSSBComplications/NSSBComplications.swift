//
//  NSSBComplications.swift
//  NSSBComplications
//
//  Watch face complications (WidgetKit). Shows today's breaks and money saved,
//  or a live countdown while a break is running.
//  Data comes from the watch app through SharedContainer (App Group).
//

import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct BreakEntry: TimelineEntry {
    let date: Date
    let breaksToday: Int
    let savedToday: Double
    let showSavings: Bool
    /// Start of the break running at `date`, nil if none
    let breakStarted: Date?

    var breakInterval: ClosedRange<Date>? {
        guard let start = breakStarted else { return nil }
        return start...start.addingTimeInterval(Date.breakLength)
    }

    /// State as it will be at `date`: a break that has ended by then counts as completed.
    static func make(at date: Date, from data: NonSmokingData) -> BreakEntry {
        var completed = data.breaks
        var running: Date? = nil
        if let start = data.breakStarted {
            if date < start.addingTimeInterval(Date.breakLength) {
                running = start
            } else if completed.contains(start) == false {
                completed.append(start)
            }
        }
        let today = completed.filter { Calendar.current.isDate($0, inSameDayAs: date) }.count
        return BreakEntry(
            date: date,
            breaksToday: today,
            savedToday: Double(today) * data.costPer20 / 20,
            showSavings: data.costPer20 > 0,
            breakStarted: running
        )
    }

    static let placeholder = BreakEntry(date: .now, breaksToday: 3, savedToday: 4.5, showSavings: true, breakStarted: nil)
    static let placeholderOnBreak = BreakEntry(date: .now, breaksToday: 2, savedToday: 3, showSavings: true, breakStarted: .now.addingTimeInterval(-90))
}

// MARK: - Provider

struct Provider: TimelineProvider {

    private var currentData: NonSmokingData {
        SharedContainer.read() ?? NonSmokingData(lastUpdate: .distantPast)
    }

    func placeholder(in context: Context) -> BreakEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (BreakEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(BreakEntry.make(at: .now, from: currentData))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BreakEntry>) -> Void) {
        let data = currentData
        let now = Date.now
        let calendar = Calendar.current
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)

        // Now, the moment a running break ends (count goes up), and midnight (count resets).
        // The countdown itself animates via timer-based views, so no per-second entries are needed.
        var dates: [Date] = [now]
        if let start = data.breakStarted {
            let end = start.addingTimeInterval(Date.breakLength)
            if end > now && end < nextMidnight { dates.append(end) }
        }
        dates.append(nextMidnight)

        Log.widget.debug("getTimeline() - \(dates.count) entries")
        completion(Timeline(entries: dates.map { BreakEntry.make(at: $0, from: data) }, policy: .after(nextMidnight)))
    }
}

// MARK: - Views

private let breakSymbol = "lungs.fill"

private func currencyText(_ value: Double) -> Text {
    Text(value, format: .currency(code: Locale.current.currency?.identifier ?? "USD").precision(.fractionLength(0...2)))
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BreakEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: CircularView(entry: entry)
            case .accessoryRectangular: RectangularView(entry: entry)
            case .accessoryCorner: CornerView(entry: entry)
            default: InlineView(entry: entry)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct CircularView: View {
    let entry: BreakEntry
    var body: some View {
        if let interval = entry.breakInterval {
            ProgressView(timerInterval: interval, countsDown: true) {
                Image(systemName: breakSymbol)
            } currentValueLabel: {
                Image(systemName: breakSymbol)
            }
            .progressViewStyle(.circular)
            .widgetAccentable()
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: breakSymbol)
                        .font(.caption2)
                        .widgetAccentable()
                    Text("\(entry.breaksToday)")
                        .font(.title3.bold())
                        .minimumScaleFactor(0.5)
                }
            }
        }
    }
}

struct RectangularView: View {
    let entry: BreakEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let interval = entry.breakInterval {
                Label("On a break", systemImage: breakSymbol)
                    .font(.headline)
                    .widgetAccentable()
                Text(timerInterval: interval, countsDown: true)
                    .monospacedDigit()
                ProgressView(timerInterval: interval, countsDown: false)
                    .labelsHidden()
            } else {
                Label("Non-smoking", systemImage: breakSymbol)
                    .font(.headline)
                    .widgetAccentable()
                Text("\(entry.breaksToday) \(entry.breaksToday == 1 ? "break" : "breaks") today")
                if entry.showSavings {
                    (Text("Saved ") + currencyText(entry.savedToday))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineView: View {
    let entry: BreakEntry
    var body: some View {
        if let interval = entry.breakInterval {
            Label {
                Text(timerInterval: interval, countsDown: true)
            } icon: {
                Image(systemName: breakSymbol)
            }
        } else {
            Label("\(entry.breaksToday) non-smoking \(entry.breaksToday == 1 ? "break" : "breaks")", systemImage: breakSymbol)
        }
    }
}

struct CornerView: View {
    let entry: BreakEntry
    var body: some View {
        if let interval = entry.breakInterval {
            Image(systemName: breakSymbol)
                .font(.title3)
                .widgetAccentable()
                .widgetLabel {
                    ProgressView(timerInterval: interval, countsDown: true)
                }
        } else {
            Text("\(entry.breaksToday)")
                .font(.title2.bold())
                .widgetAccentable()
                .widgetLabel {
                    Text(entry.breaksToday == 1 ? "break today" : "breaks today")
                }
        }
    }
}

// MARK: - Widget

@main
struct NSSBComplications: Widget {
    let kind = "NSSBComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("Non-Smoking Breaks")
        .description("Today's breaks, or your break in progress.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    NSSBComplications()
} timeline: {
    BreakEntry.placeholder
    BreakEntry.placeholderOnBreak
}

#Preview("Circular", as: .accessoryCircular) {
    NSSBComplications()
} timeline: {
    BreakEntry.placeholder
    BreakEntry.placeholderOnBreak
}
