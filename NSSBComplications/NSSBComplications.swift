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

    /// How far down the cigarette has burnt at `date`: 0 just lit, 1 down to the
    /// filter. Nil when no break is running. Same figure as `Date.breakProgress()`,
    /// computed for the entry's own moment rather than for now, because a timeline
    /// entry is drawn once for a moment that has not arrived yet.
    var burn: Double? {
        guard let start = breakStarted else { return nil }
        return min(1, max(0, date.timeIntervalSince(start) / Date.breakLength))
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

    /// How many drawings a burning cigarette is worth. See `getTimeline`.
    static let burnSteps = 60

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

        // Now, every step of a running cigarette's burn, the moment the break ends
        // (count goes up) and midnight (count resets).
        //
        // The digits still come from `Text(timerInterval:)` and tick on their own.
        // The cigarette cannot: WidgetKit draws an entry once and leaves it there,
        // so the only way to make it burn down is to hand the system a drawing for
        // each stage. `burnSteps` of them over the whole break, which at the
        // standard five minutes is one every five seconds - a step too small to
        // see, and few enough that the extension can draw them all in one go.
        var dates: [Date] = [now]
        if let start = data.breakStarted {
            let end = start.addingTimeInterval(Date.breakLength)
            if end > now {
                let step = Date.breakLength / Double(Self.burnSteps)
                for i in 1..<Self.burnSteps {
                    let tick = start.addingTimeInterval(step * Double(i))
                    if tick > now { dates.append(tick) }
                }
                if end < nextMidnight { dates.append(end) }
            }
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

/// The cigarette, lying down.
///
/// The app's cigarette stands up and burns from the top towards the filter at
/// the bottom (`CigaretteView`). This one is the same cigarette laid on its
/// side: filter at the leading edge, tobacco next, the ember at the burning end,
/// and nothing but what has already burnt away beyond it. So it empties as the
/// break runs out, and what is left at the end is a stub - which is what a
/// progress bar for a cigarette ought to look like.
///
/// Proportions and colours are the user's own `CigDesign`, the same figures the
/// app draws with, so a cigarette coloured in Customize looks like itself here.
/// Rotate it a quarter turn anticlockwise to stand it up again.
struct CigaretteBar: View {

    let design: CigDesign
    /// 0 just lit, 1 burnt down to the filter. Nil for a cigarette that is not lit.
    let progress: Double?
    /// Whether to show what has burnt away. A bar wants the full length to
    /// measure against; a cigarette standing in a circular complication is
    /// better off just getting shorter.
    var showTrack: Bool = true

    @Environment(\.widgetRenderingMode) private var renderingMode
    private var inColour: Bool { renderingMode == .fullColor }

    /// Cork paper. Fixed positions rather than `CigaretteGlowDots`' random ones:
    /// a widget redraws at every entry, and speckles that jump around between
    /// drawings read as flicker rather than as paper.
    private static let speckles: [(x: CGFloat, y: CGFloat)] = [
        (0.14, 0.30), (0.30, 0.68), (0.46, 0.22), (0.58, 0.58), (0.74, 0.36), (0.88, 0.74)
    ]

    var body: some View {
        GeometryReader { geo in

            let length = geo.size.width
            let thickness = geo.size.height
            let radius = thickness * 0.22

            // Same split as CigaretteView: the filter keeps its share, the ember
            // sits at the burning end, and the tobacco between them is what the
            // break has been eating into.
            let filterLength = length * design.filterPercentage
            let emberLength = progress == nil ? 0 : length * design.glowPercentage
            let tobaccoLength = max(0, length - filterLength - emberLength)
            let bodyLength = tobaccoLength * (1 - (progress ?? 0))

            ZStack(alignment: .leading) {

                if showTrack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill((inColour ? design.body : .white).opacity(0.14))
                }

                HStack(spacing: 0) {

                    // FILTER
                    ZStack {
                        UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: radius)
                            .fill(inColour
                                  ? AnyShapeStyle(LinearGradient(colors: design.filterArray, startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(Color.white.opacity(0.5)))
                        if inColour {
                            ForEach(Self.speckles.indices, id: \.self) { i in
                                Circle()
                                    .fill(design.filterDots)
                                    .frame(width: thickness * 0.16, height: thickness * 0.16)
                                    .offset(x: (Self.speckles[i].x - 0.5) * filterLength,
                                            y: (Self.speckles[i].y - 0.5) * thickness)
                            }
                        }
                    }
                    .frame(width: filterLength)

                    // BODY - rounded off at the end only when nothing is burning there
                    UnevenRoundedRectangle(bottomTrailingRadius: progress == nil ? radius : 0,
                                           topTrailingRadius: progress == nil ? radius : 0)
                        .fill(inColour
                              ? AnyShapeStyle(LinearGradient(colors: design.bodyArray, startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color.white))
                        .frame(width: bodyLength)

                    // EMBER - hot where it meets the tobacco, ash at the tip
                    if emberLength > 0 {
                        UnevenRoundedRectangle(bottomTrailingRadius: radius, topTrailingRadius: radius)
                            .fill(inColour
                                  ? AnyShapeStyle(LinearGradient(stops: [
                                        .init(color: design.glow, location: 0),
                                        .init(color: design.glow.opacity(0.85), location: 0.4),
                                        .init(color: design.ash, location: 0.75),
                                        .init(color: design.ashDark, location: 1)
                                    ], startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.white))
                            .frame(width: emberLength)
                            .widgetAccentable()
                    }
                }
            }
            // The glow carries past the paper. In a background rather than in the
            // stack, so that a halo wider than the cigarette does not fatten the
            // cigarette - which is exactly what it did when it was a layer of its own.
            .background(alignment: .leading) {
                if emberLength > 0, inColour {
                    RadialGradient(colors: [design.glow.opacity(0.55), design.glow.opacity(0)],
                                   center: .center, startRadius: 0, endRadius: thickness * 1.9)
                        .frame(width: thickness * 3.8, height: thickness * 3.8)
                        .offset(x: filterLength + bodyLength + emberLength / 2 - thickness * 1.9)
                }
            }
        }
    }
}

/// The same cigarette, stood upright the way the app draws it.
struct UprightCigarette: View {
    let design: CigDesign
    let progress: Double?
    var length: CGFloat = 24
    var thickness: CGFloat = 6

    var body: some View {
        CigaretteBar(design: design, progress: progress, showTrack: false)
            .frame(width: length, height: thickness)
            .rotationEffect(.degrees(-90))
            // Rotating draws sideways but leaves the layout box lying down, and a
            // tall cigarette claiming to be a wide one gets squeezed into the
            // corner slot or pushed out of the middle of a circular complication.
            // This is the footprint it actually occupies.
            .frame(width: thickness, height: length)
    }
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
            // The ring still counts down by itself, second by second, and is the
            // colour of the ember rather than white. The cigarette inside it is
            // the one being smoked, burning down a step at a time.
            ProgressView(timerInterval: interval, countsDown: true) {
                Image(systemName: breakSymbol)
            } currentValueLabel: {
                UprightCigarette(design: entry.design, progress: entry.burn)
            }
            .progressViewStyle(.circular)
            .tint(entry.design.glow)
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
                CigaretteBar(design: entry.design, progress: entry.burn)
                    .frame(height: 10)
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
            // and Gauge are allowed in a widget label - so the cigarette goes in
            // the corner itself and the gauge takes the ember's colour.
            UprightCigarette(design: entry.design, progress: entry.burn, length: 22, thickness: 6)
                .widgetAccentable()
                .widgetLabel {
                    ProgressView(timerInterval: interval, countsDown: true)
                        .tint(entry.design.glow)
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
