//
//  CompanyView.swift
//  NSSB WatchKit Extension
//

// Somebody is out here with you, seen from your wrist.
//
// The phone draws this as a journey: somebody standing across the courtyard
// comes over, the two tips touch, a cigarette catches, and they straighten up
// beside you. None of that can happen here, because none of it is the watch's
// to do - there is no courtyard on a wrist for anybody to walk out of, and the
// handoff has already happened in a pocket by the time the payload arrives.
// Drawing a walk from nowhere would be an animation of something that did not
// occur.
//
// So this is the last frame of the phone's journey and nothing before it: the
// moment they are simply standing there. They fade in where they stand, they
// burn on their own clock, and they go when their cigarette does.
//
// Everything else follows the phone. Their own design rather than a copy of
// yours, their name along their cigarette, the wash of their colour behind
// them, and the side of you they were given there - so a glance at the wrist
// and a look at the phone show the same two people in the same two places.

import SwiftUI
import Combine

struct CompanyView: View {

    /// Who the phone says is standing with you.
    let company: BreakCompany

    /// Your own cigarette, which theirs is measured against.
    let mine: CigDesign

    /// Your own break. Nil means you are not smoking, and company without a
    /// cigarette of your own is nobody: the phone will say so in a moment,
    /// and until it does this says it already.
    ///
    /// This is the half of the stale-payload guard that the payload cannot
    /// carry. A break stubbed out on the watch is over here first - the phone
    /// hears about it, clears its courtyard, and sends an empty company back
    /// - and for that round trip the only thing that knows the truth is this.
    let yourBreak: Date?

    /// Your own cigarette's height, which is the whole screen.
    let height: CGFloat

    /// Everybody already standing, no fade. Used by a renderer that cannot
    /// wait for an animation it is not running; the app never passes it.
    var settled: Bool = false

    var body: some View {

        // The timer lives one level down so that it only exists while
        // somebody does. A watch should not be ticking once a second for a
        // courtyard nobody is standing in.
        if yourBreak != nil, company.isEmpty == false {
            StandingWithYouView(company: company, mine: mine, height: height, settled: settled)
        }
    }
}

/// The people, once there are some.
private struct StandingWithYouView: View {

    let company: BreakCompany
    let mine: CigDesign
    let height: CGFloat
    let settled: Bool

    /// One clock for everybody, because everybody is drawn in one frame.
    /// A computed burn position only moves when something publishes, and
    /// nothing else here publishes once a second.
    @State private var now: Date = .now
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {

        ZStack {

            ForEach(company.standing(at: now)) { companion in

                let side: CGFloat = companion.onLeft ? -1 : 1
                let theirs = height * CompanionCigaretteView.depth * companion.design.widthPercentage

                // Measured from the two cigarettes rather than from the
                // screen, so a wide cigarette and a narrow one both end up
                // with the same gap between them. Nothing hangs beside your
                // own here - the title and the share button are the phone's
                // - so the gap is a gap rather than the phone's clearance.
                let rest = height * mine.widthPercentage / 2 + height * 0.055 + theirs / 2

                CompanionCigaretteView(
                    companion: companion,
                    height: height,
                    now: now,
                    settled: settled
                )
                .offset(x: side * rest)
                .transition(.opacity)
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 0.3), value: company)
        .onReceive(clock) { now = $0 }
    }
}

/// One person, standing beside you for the rest of their cigarette.
struct CompanionCigaretteView: View {

    /// How tall somebody beside you is, against your own cigarette.
    ///
    /// Shorter, because they are a step further back than the cigarette in
    /// your own hand - and because at full height on a screen this size
    /// three cigarettes side by side is a fence rather than a courtyard.
    static let depth: CGFloat = 0.62

    let companion: BreakCompany.Companion

    /// Your own cigarette's height.
    let height: CGFloat

    /// The clock they burn on, which is the one everybody here burns on.
    let now: Date

    var settled: Bool = false

    /// How much of them has arrived. Opacity is not what carries this -
    /// the worst a missed animation can do is put them there without the
    /// fade, rather than leave them correctly placed and invisible, which
    /// is a bug this project has already had once.
    @State private var arrived: Double

    init(companion: BreakCompany.Companion,
         height: CGFloat,
         now: Date,
         settled: Bool = false) {

        self.companion = companion
        self.height = height
        self.now = now
        self.settled = settled

        _arrived = State(initialValue: settled ? 1 : 0)
    }

    private var design: CigDesign { companion.design }

    private var full: CGFloat { height * Self.depth }
    private var progress: Double { companion.progress(at: now) }

    private var width: CGFloat { max(1, full * design.widthPercentage) }
    private var glowHeight: CGFloat { full * design.glowPercentage }
    private var filterHeight: CGFloat { full * design.filterPercentage }

    private var bodyHeight: CGFloat {
        let whole = (design.bodyPercentage + design.glowPercentage) * full - glowHeight
        return max(0, whole - whole * progress)
    }

    private var spacerHeight: CGFloat {
        max(0, full - (glowHeight + bodyHeight + filterHeight))
    }

    var body: some View {

        ZStack {

            // The same wash of their own colour your own cigarette has, at
            // half strength. Without it a custom design comes down to a tip
            // and a filter, and the thing that makes it theirs never reads.
            design.background
                .mask(Ellipse())
                .frame(width: full * 0.26, height: full * 1.15)
                .blur(radius: full * 0.1)
                .opacity(0.4 * arrived)

            VStack(spacing: 0) {

                Color.clear
                    .frame(width: width, height: spacerHeight)

                // The real ember, the same one your own cigarette has. The
                // courtyard's flat glow is a simplification that works
                // across a room and not at arm's length.
                CigaretteAshView(design: design, height: glowHeight, width: width)
                    .frame(width: width, height: glowHeight)

                LinearGradient(gradient: Gradient(colors: design.bodyArray),
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: width, height: bodyHeight)

                ZStack {

                    LinearGradient(gradient: Gradient(colors: design.filterArray),
                                   startPoint: .leading, endPoint: .trailing)

                    CigaretteGlowDots(height: filterHeight, width: width,
                                      color: design.filterDots, animated: false)
                }
                .frame(width: width, height: filterHeight)
            }
            .frame(width: width, height: full)

            // Their name, written along their cigarette the way the phone
            // writes it. It is the only text out here: your own cigarette
            // wears its name on the phone and not on the wrist, and theirs
            // is the one thing on this screen you cannot work out by
            // looking at it.
            //
            // On the far side of them, so nothing is written in the gap
            // between the two cigarettes.
            Text(companion.name)
                .font(.system(size: 11, weight: .medium))
                .fixedSize()
                .foregroundStyle(.gray)
                .frame(width: full, alignment: .trailing)
                .rotationEffect(.degrees(90), anchor: .center)
                .offset(x: (companion.onLeft ? -1 : 1) * (width / 2 + 9), y: 0)
                .frame(width: width)
                .opacity(0.85 * arrived)
        }
        .frame(width: width, height: height)
        .opacity(0.35 + 0.65 * arrived)

        // Attached to the value rather than wrapped around it: a
        // withAnimation that runs while SwiftUI is still settling a newly
        // inserted view gets swallowed, and this view is newly inserted at
        // exactly the moment that matters.
        .animation(.easeOut(duration: 0.45), value: arrived)
        .task { arrived = 1 }
    }
}

#Preview {

    var mine = CigDesign()
    let _ = { mine.widthPercentage = 0.12 }()

    var theirs = CigDesign()
    let _ = {
        theirs.title = "Paper Kestrel"
        theirs.body = Color(red: 0.78, green: 0.76, blue: 0.72)
        theirs.filter = Color(red: 0.86, green: 0.55, blue: 0.18)
        theirs.background = Color(red: 0.85, green: 0.42, blue: 0.12)
    }()

    let company = BreakCompany(beside: [
        BreakCompany.Companion(id: "one", name: "Paper Kestrel", design: theirs,
                               startedAt: .now.addingTimeInterval(-60), onLeft: true),
        BreakCompany.Companion(id: "two", name: "Charcoal Gull", design: CigDesign(),
                               startedAt: .now.addingTimeInterval(-150), onLeft: false)
    ])

    return GeometryReader { geo in
        ZStack {
            Color.black
            CompanyView(company: company, mine: mine, yourBreak: .now, height: geo.size.height)
        }
    }
    .ignoresSafeArea()
}
