//
//  BesideYouView.swift
//  NSSB
//

// One cigarette, one journey.
//
// Somebody is standing out there in the dark. They come over, lean in until
// the two tips touch, a cigarette catches, and they straighten up beside you
// for the rest of the break.
//
// That used to be three views in a row: a dark cigarette at a courtyard
// position, a handoff drawn in a different coordinate space with a different
// renderer, and then a companion that appeared afterwards and zoomed in from
// nowhere. Three views means three arrivals, and that is exactly what it
// looked like - the cigarette blinked out between each pair, changed size and
// changed model.
//
// So now it is one view per person, held by name from the moment they are
// standing out there to the moment their cigarette goes out. Nothing is
// swapped mid-animation, which is the only way an animation can be smooth:
// by being one animation.
//
// Everything in here is an offset from where that person's lit end finally
// comes to rest, because that is the one point every part of the journey has
// to agree about.

import SwiftUI

/// Somebody in your immediate company: on their way over, or standing there.
///
/// The same value covers both, which is the point. When the handoff ends this
/// person's `handoff` goes nil and nothing else about them changes, so the
/// view keeps its identity and simply carries on moving.
struct Visitor: Identifiable {

    let companion: Companion

    /// Where they set off from - their own spot in the courtyard, as a
    /// fraction of the screen. Nobody appears beside your hand out of
    /// nothing; they come from where they were standing.
    let from: CGPoint

    /// How far back they were, which is how small they start.
    let depth: Double

    /// The two tips touching, while that is happening. Nil for somebody who
    /// is simply standing there - including this same person, a moment later.
    let handoff: Handoff?

    /// Where they end up once the tips have touched.
    var goes: Destination = .besideYou

    /// The document they came from, not their name. Two people can be
    /// called the same thing, and the same person coming back out certainly
    /// is - and keying this on the name made them one entry, so the one
    /// standing beside you was replaced by the one walking over.
    var id: String { companion.id }

    /// There are two places beside you, and that is all there are.
    enum Destination: Equatable {

        /// There is room, and they stay for the rest of their cigarette.
        case besideYou

        /// Both sides of you are taken, or theirs has almost burned away.
        /// The light was still theirs to have - capping the company is
        /// reasonable, capping that is not - so they take it and go back to
        /// where the rest of the courtyard is standing.
        case backOutside(CGPoint)
    }

    /// The handoff, from whichever side of it you are on.
    ///
    /// Both sides see one thing: somebody comes over, the tips touch, a
    /// cigarette catches. Only which cigarette differs, so that is the only
    /// thing this has to say.
    struct Handoff {

        /// True when theirs is the cigarette that catches, which is to say
        /// you are the one giving the light. False when yours catches.
        let theirsCatches: Bool

        /// The tips are touching. Whichever cigarette catches, catches now.
        let onContact: () -> Void

        /// They are straightening up where they will stand.
        ///
        /// Called as that last movement begins rather than after it. The old
        /// order was what made one arrival look like two: the handoff
        /// finished, its view was taken away, the state changed, and a
        /// second view appeared to do the walk. Calling it here lets the
        /// state catch up without interrupting anything.
        let onSettled: () -> Void
    }
}

/// Everybody who is out here with you, in your own cigarette's frame.
///
/// Drawn as an overlay on your cigarette, so the coordinate space is your
/// cigarette: the meeting point is your lit end, wherever it has burned down
/// to. Your own cigarette is never a copy drawn on top - it is the real one,
/// and the reason an ember appears at contact is that the break genuinely
/// starts there.
struct BesideYouView: View {

    let people: [Visitor]

    /// Your own cigarette, which everything here is measured against.
    let mine: CigDesign
    let height: CGFloat

    /// How far down your own cigarette your lit end has got, 0 to 1.
    let yourProgress: Double

    /// The screen the courtyard is drawn across, so a walk can start at the
    /// spot somebody was actually standing on rather than at a guess.
    let courtyard: CGSize

    /// Everybody already standing where they end up, no journey. Used by the
    /// still renderer, which cannot wait for an animation it is not running.
    var settled: Bool = false

    var body: some View {

        GeometryReader { me in

            // Where this overlay sits on the screen the courtyard is drawn
            // across. Without this the walk has to start at a made-up point
            // beside your hand, which is how somebody could set off from one
            // place and be drawn standing in another.
            let here = me.frame(in: .named(Courtyard.space))

            ZStack {

                ForEach(people) { visitor in

                    let side: CGFloat = visitor.companion.side == .left ? -1 : 1
                    let theirs = height * visitor.companion.design.widthPercentage

                    // Measured from the two cigarettes rather than from the
                    // layout frame, and clear of what already hangs beside
                    // your own: the share button to the right of it, the
                    // title to the left.
                    let rest = height * mine.widthPercentage / 2 + 52 + theirs / 2
                    let centre = CGSize(width: side * rest, height: 0)

                    VisitorCigaretteView(
                        visitor: visitor,
                        height: height,
                        mirrored: side < 0,
                        from: less(spot(visitor.from, from: here), centre),
                        leaves: leaving(visitor).map { less(spot($0, from: here), centre) },
                        distant: height * (0.17 + visitor.depth * 0.25),
                        meeting: less(yourTip, centre),
                        settled: settled
                    )
                    .offset(centre)
                    .transition(.opacity)
                }
            }
            .frame(width: me.size.width, height: me.size.height)
        }
        .allowsHitTesting(false)
    }

    /// Where somebody with nowhere to stand goes back to, if they do.
    private func leaving(_ visitor: Visitor) -> CGPoint? {
        guard case .backOutside(let spot) = visitor.goes else { return nil }
        return spot
    }

    /// A courtyard spot, as an offset from the centre of this overlay.
    private func spot(_ at: CGPoint, from here: CGRect) -> CGSize {
        CGSize(
            width: courtyard.width * at.x - here.midX,
            height: courtyard.height * at.y - here.midY
        )
    }

    /// Your own lit end, as an offset from the centre of this overlay.
    ///
    /// What has burned away is empty space above the ember, so this travels
    /// down your cigarette as the break goes - which is why a handoff has to
    /// ask where your tip is rather than assume it is at the top.
    private var yourTip: CGSize {
        CGSize(
            width: 0,
            height: mine.tipOffset(height: height, progress: yourProgress)
                + height * mine.glowPercentage / 2
                - height / 2
        )
    }
}

/// One person, the whole way: out there, coming over, and standing with you.
struct VisitorCigaretteView: View {

    let visitor: Visitor

    /// Your own cigarette's height. Theirs is drawn at the same height,
    /// because they are not across the courtyard any more - they are here -
    /// and scaled down for as long as they are not.
    let height: CGFloat

    /// Which side of you they stand on. Their name hangs on the far side, so
    /// nothing is written in the gap between the two cigarettes.
    var mirrored: Bool = false

    /// Where their lit end starts, as an offset from where it comes to rest.
    let from: CGSize

    /// Where they go once the tips have touched, when there is nowhere
    /// beside you for them to stand. Nil when they are staying.
    let leaves: CGSize?

    /// How tall they were out there.
    let distant: CGFloat

    /// Your own lit end, as an offset from where theirs comes to rest.
    let meeting: CGSize

    /// Skip the journey and simply stand there. The app never passes this.
    var settled: Bool = false

    @State private var phase: Phase
    @State private var lit: Bool

    /// Whether this one came with a handoff, remembered rather than read.
    /// By the time the last movement starts, the state behind this view has
    /// already been told the handoff is over - so asking it then would get
    /// the wrong answer about how long that movement should take.
    @State private var ceremony: Bool

    /// Their own clock. A computed burn position only changes when something
    /// else happens to publish, so theirs ticks for itself, from their own
    /// ignition instant.
    @State private var now: Date = .now
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(visitor: Visitor,
         height: CGFloat,
         mirrored: Bool = false,
         from: CGSize,
         leaves: CGSize? = nil,
         distant: CGFloat,
         meeting: CGSize,
         settled: Bool = false) {

        self.visitor = visitor
        self.height = height
        self.mirrored = mirrored
        self.from = from
        self.leaves = leaves
        self.distant = distant
        self.meeting = meeting
        self.settled = settled

        _phase = State(initialValue: settled ? .standing : .away)
        _ceremony = State(initialValue: visitor.handoff != nil)

        // Unlit only while they are the one who needs the light. Somebody
        // who came over to light you was already smoking, and somebody who
        // lit at the same instant as you is lit by definition.
        _lit = State(initialValue: settled || visitor.handoff?.theirsCatches != true)
    }

    /// Five beats and about two and a half seconds, which is slower than it
    /// needs to be to convey the information. That is the point: this is the
    /// one moment in the app worth watching.
    enum Phase { case away, leaning, touching, caught, standing, leaving }

    // MARK: Their cigarette

    private var design: CigDesign { visitor.companion.design }

    /// Zero until it is lit, which is the whole of what an unlit cigarette
    /// looks like: a full body and nothing at the end of it.
    private var progress: Double { lit ? visitor.companion.progress(at: now) : 0 }

    private var width: CGFloat { max(1, height * design.widthPercentage) }
    private var glowHeight: CGFloat { lit ? height * design.glowPercentage : 0 }
    private var filterHeight: CGFloat { height * design.filterPercentage }

    private var bodyHeight: CGFloat {
        let full = (design.bodyPercentage + design.glowPercentage) * height - glowHeight
        guard lit else { return full }
        return max(0, full - full * progress)
    }

    private var spacerHeight: CGFloat {
        max(0, height - (glowHeight + bodyHeight + filterHeight))
    }

    // MARK: Where they are

    /// Where their lit end sits inside the frame, as a fraction of its
    /// height. Both the scaling and the lean happen about exactly this
    /// point, so the tip stays where it is put however small or however far
    /// over the cigarette is - and so the ember grows at the meeting point
    /// rather than shunting the cigarette along when it catches.
    private var tipFraction: Double { (spacerHeight + glowHeight / 2) / height }

    private var tipAnchor: UnitPoint { UnitPoint(x: 0.5, y: tipFraction) }

    /// Where the tip already is, which every target is measured against.
    private var tipRest: CGSize {
        CGSize(width: 0, height: tipFraction * height - height / 2)
    }

    /// Leaning in. Clockwise from the left, so the tip tilts towards your
    /// cigarette and the body trails away behind it - the V you make when
    /// you light one off somebody else's.
    private var lean: Double { mirrored ? 38 : -38 }

    /// A hand's width short of contact, held back along the cigarette's own
    /// body so the approach reads as leaning in rather than sliding sideways.
    private var held: CGSize {
        let radians = lean * .pi / 180
        let gap = height * 0.07
        return CGSize(
            width: meeting.width - sin(radians) * gap,
            height: meeting.height + cos(radians) * gap
        )
    }

    /// A hair past the meeting point, because two cigarettes being lit off
    /// each other overlap. A gap of one pixel reads as not quite touching,
    /// and not quite touching is the whole thing failing.
    private var contact: CGSize {
        CGSize(width: meeting.width, height: meeting.height - width * 0.06)
    }

    private var offset: CGSize {
        switch phase {
        case .standing:          return .zero
        case .away:              return less(from, tipRest)
        case .leaning:           return less(held, tipRest)
        case .touching, .caught: return less(contact, tipRest)
        case .leaving:           return less(leaves ?? from, tipRest)
        }
    }

    private var scale: CGFloat {
        switch phase {
        case .away, .leaving:              return max(distant / height, 0.05)
        case .leaning, .touching, .caught: return 0.62
        case .standing:                    return 1
        }
    }

    private var angle: Double {
        switch phase {
        case .away, .standing, .leaving:   return 0
        case .leaning, .touching, .caught: return lean
        }
    }

    /// Near, but never competing with the cigarette in your own hand.
    ///
    /// Opacity is not what carries the arrival, and it used to be: when the
    /// animation did not run, somebody was in the right place and completely
    /// invisible. The worst a missed animation can do now is put them there
    /// without the walk.
    private var opacity: Double {
        switch phase {
        case .away:              return 0.6
        case .leaning:           return 0.92
        case .touching, .caught: return 1
        case .standing:          return 0.9
        case .leaving:           return 0
        }
    }

    /// How much of them has arrived, for everything that belongs to being
    /// here rather than out there: their colour on the wall, their name.
    private var arrived: Double {
        switch phase {
        case .away, .leaving:      return 0
        case .leaning, .touching:  return 0.35
        case .caught:              return 0.7
        case .standing:            return 1
        }
    }

    /// The light at the meeting point. Nothing before they are close, most
    /// of it as the tip catches, and a warmth left over as they straighten up.
    private var bloom: Double {
        switch phase {
        case .away, .leaving: return 0
        case .leaning:        return 0.12
        case .touching:       return 0.65
        case .caught:         return 1
        case .standing:       return 0
        }
    }

    /// Whichever tip is already alight is the one lighting the other.
    private var flame: Color { design.glow }

    /// How long it takes to get to wherever they are now.
    ///
    /// Attached to the change rather than wrapped around it. A
    /// `withAnimation` that runs while SwiftUI is still settling a newly
    /// inserted view gets swallowed, and this view is newly inserted for
    /// the first and most important movement of the five. This way the
    /// animation belongs to `phase` wherever it is set from.
    ///
    /// Slower than it needs to be to convey the information, which is the
    /// point: this is the one moment in the app worth watching.
    private var curve: Animation {
        switch phase {
        case .away:     return .easeOut(duration: 0.3)
        case .leaning:  return .easeInOut(duration: 0.78)
        case .touching: return .easeOut(duration: 0.24)
        case .caught:   return .easeOut(duration: 0.3)
        case .leaving:  return .easeInOut(duration: 0.9)
        case .standing: return ceremony ? .easeInOut(duration: 0.9) : .easeOut(duration: 1.1)
        }
    }

    var body: some View {

        ZStack {

            // Drawn under them, so the two tips sit inside one pool of light
            // rather than one glowing in front of the other.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [flame.opacity(0.95), flame.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: width * 0.9
                    )
                )
                .frame(width: width * 1.8, height: width * 1.8)
                .scaleEffect(0.35 + bloom * 1.15)
                .opacity(bloom)
                .blur(radius: width * 0.18)
                .offset(meeting)

            person
                .scaleEffect(scale, anchor: tipAnchor)
                .rotationEffect(.degrees(angle), anchor: tipAnchor)
                .offset(offset)
                .opacity(opacity)
        }
        .frame(width: width, height: height)
        .animation(curve, value: phase)
        .animation(.easeOut(duration: 0.28), value: lit)
        .onReceive(clock) { now = $0 }
        .task { await walk() }
    }

    /// Them, upright, at full size - every transform above is applied to
    /// this one thing, which is what makes the journey one movement.
    private var person: some View {

        ZStack {

            // A halo while they are still out there, exactly as the
            // courtyard draws somebody asking: a dark cigarette in a dark
            // courtyard is almost nothing to look at, and this is the same
            // person the courtyard was drawing a moment ago.
            if visitor.handoff?.theirsCatches == true {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [design.background.opacity(0.5), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: height * 0.42
                        )
                    )
                    .frame(width: height * 0.9, height: height * 0.9)
                    .blur(radius: height * 0.05)
                    .opacity(1 - arrived)
            }

            // The same wash of their own colour your cigarette has, at half
            // strength, and only once they are actually here. Without it a
            // custom design comes down to a tip and a filter, and the thing
            // that makes it theirs never reads.
            design.background
                .mask(Ellipse())
                .frame(width: height * 0.22, height: height * 1.1)
                .blur(radius: height * 0.09)
                .opacity(0.4 * arrived)

            VStack(spacing: 0) {

                Color.clear
                    .frame(width: width, height: spacerHeight)

                // The real ember, not the flat glow the courtyard draws.
                // Across the courtyard that simplification is invisible;
                // standing here at full height beside a cigarette that is
                // burning properly, it read as an unlit tip painted orange.
                if lit {
                    CigaretteAshView(design: design, height: glowHeight, width: width)
                        .frame(width: width, height: glowHeight)
                }

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
            .frame(width: width, height: height)

            // Their name, at the size your own is, because their cigarette
            // is the size yours is. Where they are in their own day travels
            // with it: a flag and a sun or a moon belong to the person, and
            // reading them off a line at the bottom of the screen meant
            // matching them back up to a cigarette by guesswork.
            HStack(spacing: 5) {

                Text(visitor.companion.name)

                // Turned back upright, because the label is turned on its
                // side and a flag on its side is not a flag. The name reads
                // along the cigarette the way yours does; these two are
                // pictures, and a picture has one way up.
                // The square is what keeps them inside the line. A
                // rotation does not change the space a view is given, so a
                // wide glyph turned on its side hangs out of its slot and
                // over the cigarette next to it.
                if let flag = visitor.companion.flag {
                    Text(flag)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 22, height: 22)
                }

                DaylightView(daylight: visitor.companion.daylight(at: now))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
            }
            .font(.headline)
            .fixedSize()
            .foregroundStyle(.gray)
            .frame(width: height, alignment: .trailing)
            .rotationEffect(.degrees(90), anchor: .center)
            .offset(x: (mirrored ? -1 : 1) * (width / 2 + 15), y: 0)
            .frame(width: width)
            .opacity(0.8 * arrived)
        }
    }

    // MARK: The journey

    private func walk() async {

        guard phase != .standing else { return }

        // One frame where they are still out there, to move away from. A
        // withAnimation that runs while SwiftUI is settling an insert gets
        // swallowed, and a swallowed arrival is indistinguishable from
        // somebody who teleported.
        await Task.yield()

        guard let handoff = visitor.handoff else {

            // They lit where they stood, at the same instant as you. No tips
            // touched, so there is nothing to wait for - they just walk over.
            phase = .standing
            return
        }

        phase = .leaning
        await pause(0.78)

        phase = .touching
        await pause(0.26)

        // The tips are together. Whichever cigarette catches, catches now,
        // and the ember that appears is the real one.
        handoff.onContact()
        if handoff.theirsCatches { lit = true }

        phase = .caught
        await pause(0.6)

        guard case .besideYou = visitor.goes else {

            // Nowhere for them to stand. They got what they came for and go
            // back to the courtyard, which is where they were anyway - and
            // which is a great deal better than standing on top of whoever
            // is already beside you, which is what this used to do.
            phase = .leaving
            await pause(0.95)
            handoff.onSettled()
            return
        }

        // The state behind this view and the last movement, together.
        handoff.onSettled()
        phase = .standing
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

/// One offset measured from another, because all of this is offsets.
private func less(_ a: CGSize, _ b: CGSize) -> CGSize {
    CGSize(width: a.width - b.width, height: a.height - b.height)
}

#Preview {

    var mine = CigDesign()
    let _ = { mine.title = "Sunlit Parchment" }()

    var theirs = CigDesign()
    let _ = {
        theirs.title = "Paper Kestrel"
        theirs.body = Color(red: 0.78, green: 0.76, blue: 0.72)
        theirs.filter = Color(red: 0.86, green: 0.55, blue: 0.18)
        theirs.background = Color(red: 0.85, green: 0.42, blue: 0.12)
    }()

    var wait = BreakWait.opening(uid: "preview", design: theirs)
    let _ = { wait.paired = true }()

    let screen = CGSize(width: 402, height: 874)
    let height = screen.height * 0.7

    return GeometryReader { _ in
        BesideYouView(
            people: [Visitor(companion: Companion(waiter: wait, litAt: .now),
                             from: CGPoint(x: 0.2, y: 0.3),
                             depth: 0.5,
                             handoff: nil)],
            mine: mine,
            height: height,
            yourProgress: 0.3,
            courtyard: screen
        )
    }
    .frame(width: screen.width, height: screen.height)
    .background(.black)
    .coordinateSpace(name: Courtyard.space)
}
