//
//  WaitForCompanyView.swift
//  NSSB
//

// Layer 3, from the outside: stepping out and waiting for somebody to start
// with, then smoking next to them.
//
// Sits in the same row as "got a light?", in the same voice, and with the
// same shape of life: an offer, a drain, and a line that says what happened.
// The one difference is that this offer does not need anybody to be lit -
// you are waiting for somebody else who is also standing there unlit, and
// they do not show up in the count. It is the only social thing in the app
// that works in a courtyard with nobody in it.

import SwiftUI

/// The one thing you can do before lighting up.
///
/// There used to be two offers side by side here - "got a light?" and "wait
/// for someone" - because underneath there are two mechanisms. That was the
/// plumbing showing through. Nobody standing outside has two intentions;
/// they have one, and it is that they would rather not smoke alone. So there
/// is one line, one tap, and one bar, and which of the two mechanisms
/// answers is never something the person has to know.
struct ReachOutView: View {

    let state: Outreach

    /// Only an unlit cigarette has anything to reach out for.
    let unlit: Bool

    let reach: () -> Void

    /// Called once the line about what happened has been up long enough to
    /// read. Without it the row would go on saying "nobody came out" for the
    /// whole five minutes, and the offer would never come back.
    let clear: () -> Void

    var body: some View {

        // A fixed row rather than one that appears and disappears: the
        // cigarette must not shuffle up and down the screen because somebody
        // somewhere lit up.
        ZStack {

            switch state {

            case .idle:

                // No count test any more. The old ask needed somebody lit to
                // answer it, so offering in an empty courtyard was an
                // eight-second pause with a foregone conclusion. Half of this
                // gesture is a wait, which anybody unlit can answer - so it
                // is worth offering even when there is nobody out there yet.
                if unlit {
                    Text("got a light?")
                        .font(.footnote)
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().stroke(Color.accent.opacity(0.5), lineWidth: 1)
                        )
                        .contentShape(Capsule())
                        .onTapGesture(perform: reach)
                        .transition(.opacity)
                }

            case .reaching(let until):
                ReachingLineView(until: until)
                    .transition(.opacity)

            case .lit(let giver):
                line("\(giver.name) is giving you a light")

            case .answered(let giver):
                line("\(giver.name) gave you a light")

            case .together(let companion):

                // For as long as they are out here, because this is who you
                // are standing with rather than something that just happened.
                // Their name, their flag and their clock - the same three
                // things a tapped stranger tells you, and nothing more.
                HStack(spacing: 6) {
                    Text("with \(companion.name)")
                    if let flag = companion.flag {
                        Text(flag)
                    }
                    Text("· \(companion.localTimeString()) there")
                }
                .font(.footnote)
                .foregroundStyle(.gray)
                .transition(.opacity)

            case .alone:
                line("nobody came out - lighting your own")
            }
        }
        .task(id: isOver) {
            guard isOver else { return }
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard Task.isCancelled == false else { return }
            clear()
        }
        .frame(height: 30)
        .animation(.easeInOut(duration: 0.3), value: state)
    }

    /// Both endings that need clearing: nobody came, or somebody lit you and
    /// had too little left of their own to stay.
    private var isOver: Bool {
        switch state {
        case .alone, .answered: return true
        default: return false
        }
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.gray)
            .transition(.opacity)
    }
}

/// The wait, draining.
///
/// Half a minute of standing about is long enough to wonder whether the app
/// has forgotten you, so the bar is the reassurance that this ends by itself.
/// It drains once for the whole gesture: the ask underneath gives up earlier
/// than the wait does, and that seam is not the person's business.
private struct ReachingLineView: View {

    /// When the longer half gives up. From the document rather than from
    /// now, so a slow round trip eats into the wait instead of extending it.
    let until: Date

    @State private var left: Double = 1

    var body: some View {

        VStack(spacing: 5) {

            Text("asking the courtyard")
                .font(.footnote)
                .foregroundStyle(.gray)

            Capsule()
                .fill(Color.accent.opacity(0.7))
                .frame(width: 90 * left, height: 2)
                .frame(width: 90, alignment: .leading)
        }
        // Keyed on the deadline, not just on appearing: the ask is usually
        // written a moment before the wait, so this view's first deadline is
        // the short one and it has to pick up the long one when it arrives.
        .task(id: until) {
            left = 1
            await Task.yield()
            withAnimation(.linear(duration: max(until.timeIntervalSinceNow, 0.2))) {
                left = 0
            }
        }
    }
}

/// What you learn by tapping somebody who is waiting.
///
/// The same card as every other stranger's, with the second of the two
/// buttons in this app that do something to another person. Taking the chair
/// is not asking permission - the chair is free, and nobody is refused.
struct WaitDetailView: View {
    
    let wait: BreakWait
    let join: () -> Void
    
    var body: some View {
        
        VStack(spacing: 8) {
            
            VStack(spacing: 2) {
                
                Text(wait.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack(spacing: 6) {
                    if let flag = wait.flag {
                        Text(flag)
                    }
                    Text("\(wait.localTimeString()) there")
                }
                .font(.footnote)
                .foregroundStyle(.gray)
            }
            
            Text("smoke with them")
                .font(.footnote)
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().stroke(Color.accent.opacity(0.6), lineWidth: 1)
                )
                .contentShape(Capsule())
                .onTapGesture(perform: join)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

/// The person you are smoking with, standing next to your own cigarette.
///
/// Drawn from your own clock rather than from the network, which is the one
/// real dividend of starting together: you lit at the same instant, so their
/// burn position is your burn position for the whole five minutes and there
/// is nothing to keep in sync. Their cigarette goes out when yours does
/// because it was always going to.
struct CompanionCigaretteView: View {
    
    let companion: Companion

    let height: CGFloat

    /// Which side of you they are standing on. Their name hangs on the far
    /// side, so nothing is written in the gap between the two cigarettes.
    var mirrored: Bool = false

    /// How they got here, which is the only thing that decides how they
    /// arrive. Nobody should appear beside your hand out of nothing.
    var arrival: CompanionArrival = .fromTheDark

    /// How far out they finally stand, so somebody walking over from your
    /// lit end starts at your cigarette rather than near it.
    var restingOffset: CGFloat = 0

    @State private var settled = false

    /// Their own clock.
    ///
    /// This used to be handed your burn position, on the reasoning that you
    /// lit together so there was nothing to keep in sync. That was true of
    /// the only way company could happen then, and it is false now that
    /// somebody already burning can stop and light you. It was also frozen:
    /// a computed value only changes when something else happens to publish,
    /// so it ticks for itself now, from their ignition instant.
    @State private var now: Date = .now
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: Double { companion.progress(at: now) }

    private var design: CigDesign { companion.design }
    private var width: CGFloat { max(1, height * design.widthPercentage) }
    private var glowHeight: CGFloat { height * design.glowPercentage }
    private var filterHeight: CGFloat { height * design.filterPercentage }

    /// The body is what burns away, at their pace.
    private var bodyHeight: CGFloat {
        let full = (design.bodyPercentage + design.glowPercentage) * height - glowHeight
        return max(0, full - full * progress)
    }

    private var spacerHeight: CGFloat {
        max(0, height - (glowHeight + bodyHeight + filterHeight))
    }

    var body: some View {

        ZStack {

            // The same wash of their own colour your cigarette has, at half
            // strength. Without it a custom design comes down to a tip and a
            // filter, and the thing that makes it theirs never reads.
            design.background
                .mask(Ellipse())
                .frame(width: height * 0.22, height: height * 1.1)
                .blur(radius: height * 0.09)
                .opacity(0.4)

            VStack(spacing: 0) {

                Color.clear
                    .frame(width: width, height: spacerHeight)

                // The real ember, not the flat glow the courtyard draws.
                // Across the courtyard that simplification is invisible; here
                // it is standing at full height beside a cigarette that is
                // burning properly, and it read as an unlit tip painted
                // orange - which is exactly what it was.
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
            .frame(width: width, height: height)

            // Quieter than your own name, which sits on the other side of
            // your cigarette in white. Theirs is a label on somebody else's
            // cigarette, not a title.
            Text(companion.name)
                .font(.caption2)
                .fixedSize()
                .foregroundStyle(.gray)
                .frame(width: height, alignment: .trailing)
                .rotationEffect(.degrees(90), anchor: .center)
                .offset(x: (mirrored ? -1 : 1) * (width / 2 + 9), y: 0)
                .opacity(0.8)
        }
        // Near, but never competing with the cigarette in your own hand.
        .opacity(settled ? 0.9 : 0)
        .offset(entry)
        .onReceive(clock) { now = $0 }
        .onAppear {
            withAnimation(.easeOut(duration: arrival.duration)) { settled = true }
        }
    }

    /// Where they come in from, measured back from where they end up.
    private var entry: CGSize {

        guard settled == false else { return .zero }

        // Toward you is whichever way your cigarette is from theirs.
        let inward: CGFloat = mirrored ? restingOffset : -restingOffset

        switch arrival {

        case .fromYourTip:
            // The handoff left them with their tip against yours, up at the
            // top of the frame. So they walk back out and their ember comes
            // down to where it actually is - which is the movement that was
            // missing, and why it read as a jump.
            return CGSize(width: inward, height: -height * progress * 0.7)

        case .fromTheDark:
            // No handoff happened here. They were never near your hand, so
            // they step in from further out, which is all the courtyard has
            // ever shown of somebody arriving.
            return CGSize(width: -inward * 0.22, height: 0)
        }
    }
}

/// The two ways somebody ends up standing next to you.
enum CompanionArrival {

    /// They stopped and lit you. The handoff just put them at your lit end.
    case fromYourTip

    /// They lit at the same instant as you, from wherever they were.
    case fromTheDark

    var duration: TimeInterval {
        switch self {
        case .fromYourTip: return 0.75
        case .fromTheDark: return 1.1
        }
    }
}

#Preview {
    
    var design = CigDesign()
    design.title = "Charcoal Gull"
    
    let outgoing = BreakWait.opening(uid: "preview", design: design)
    let together = Companion(waiter: outgoing, litAt: .now)

    // Somebody who stopped to light you: already two fifths through their
    // own, so they will go back inside well before you do.
    let lighter = Companion(
        giver: AskGiver(claimed(design))!,
        metAt: .now
    )

    return VStack(spacing: 40) {

        ReachOutView(state: .idle, unlit: true, reach: {}, clear: {})
        ReachOutView(state: .reaching(until: outgoing.expiresAt), unlit: true, reach: {}, clear: {})
        ReachOutView(state: .together(together), unlit: false, reach: {}, clear: {})
        ReachOutView(state: .alone, unlit: true, reach: {}, clear: {})

        WaitDetailView(wait: outgoing, join: {})

        HStack(spacing: 40) {
            CompanionCigaretteView(companion: together, height: 180)
            CompanionCigaretteView(companion: lighter, height: 180, mirrored: true)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
}

/// An ask that somebody already two fifths through their own answered.
private func claimed(_ design: CigDesign) -> BreakAsk {
    var ask = BreakAsk.opening(uid: "preview", design: design)
    ask.claimed = true
    ask.giverName = "Brass Kestrel"
    ask.giverDesign = design
    ask.giverProgress = 0.4
    ask.giverCountry = "JP"
    ask.giverTzOffset = 32400
    return ask
}
