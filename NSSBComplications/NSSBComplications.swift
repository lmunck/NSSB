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
    /// The user's own cigarette, so the wrist and the app agree about what it looks like.
    let design: CigDesign

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
            breakStarted: running,
            design: data.cigDesign
        )
    }

    static let placeholder = BreakEntry(date: .now, breaksToday: 3, savedToday: 4.5, showSavings: true, breakStarted: nil, design: CigDesign())
    static func placeholderOnBreak(burnt: Double = 0.3) -> BreakEntry {
        BreakEntry(date: .now, breaksToday: 2, savedToday: 3, showSavings: true,
                   breakStarted: .now.addingTimeInterval(-Date.breakLength * burnt), design: CigDesign())
    }
    /// The longest thing each family can be asked to draw: two digits of breaks,
    /// a savings figure with a fractional part, and no break running, which is
    /// the state with the most words in it. A preview of a typical day tells you
    /// nothing about whether a label fits; this is the one to look at.
    static let placeholderCrowded = BreakEntry(date: .now, breaksToday: 12, savedToday: 18.75, showSavings: true, breakStarted: nil, design: CigDesign())
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

        // Now, the moment the break ends (count goes up) and midnight (count
        // resets). Nothing in between, because nothing in between changes:
        // `Text(timerInterval:)` and `ProgressView(timerInterval:)` both move on
        // their own once drawn. There used to be sixty entries here, one per step
        // of a drawn cigarette burning down, because a drawing is the one thing
        // WidgetKit will not animate for you. The drawing is gone.
        var dates: [Date] = [now]
        if let start = data.breakStarted {
            let end = start.addingTimeInterval(Date.breakLength)
            if end > now, end < nextMidnight { dates.append(end) }
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
            // The system's own ring, counting itself down, with the symbol in the
            // middle. Tinted the colour of the cigarette's paper - which a watch
            // face will override with its own tint, so the colour is really for
            // the Smart Stack and the previews. What decides whether it is bright
            // or nearly black on a face is `widgetAccentable()`, not the tint.
            ProgressView(timerInterval: interval, countsDown: true) {
                Image(systemName: breakSymbol)
            } currentValueLabel: {
                Image(systemName: breakSymbol)
                    .font(.title3)
            }
            .progressViewStyle(.circular)
            .tint(entry.design.body)
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
                // Empty labels: the countdown is already on the line above, and
                // the default label would repeat it inside the bar.
                ProgressView(timerInterval: interval, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .tint(entry.design.body)
                .widgetAccentable()
                .padding(.top, 1)
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
            // The bezel gauge is the system's to draw - only Text, ProgressView
            // and Gauge are allowed in a widget label - so the symbol goes in the
            // corner itself and the gauge curves around it.
            Image(systemName: breakSymbol)
                .font(.title3)
                .widgetAccentable()
                .widgetLabel {
                    ProgressView(timerInterval: interval, countsDown: true)
                        .tint(entry.design.body)
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
    BreakEntry.placeholderCrowded
    BreakEntry.placeholderOnBreak(burnt: 0)
    BreakEntry.placeholderOnBreak(burnt: 0.45)
    BreakEntry.placeholderOnBreak(burnt: 0.9)
}

#Preview("Circular", as: .accessoryCircular) {
    NSSBComplications()
} timeline: {
    BreakEntry.placeholder
    BreakEntry.placeholderCrowded
    BreakEntry.placeholderOnBreak(burnt: 0)
    BreakEntry.placeholderOnBreak(burnt: 0.45)
    BreakEntry.placeholderOnBreak(burnt: 0.9)
}

#Preview("Corner", as: .accessoryCorner) {
    NSSBComplications()
} timeline: {
    BreakEntry.placeholder
    BreakEntry.placeholderCrowded
    BreakEntry.placeholderOnBreak(burnt: 0.45)
}

#Preview("Inline", as: .accessoryInline) {
    NSSBComplications()
} timeline: {
    BreakEntry.placeholder
    BreakEntry.placeholderCrowded
    BreakEntry.placeholderOnBreak(burnt: 0.45)
}
