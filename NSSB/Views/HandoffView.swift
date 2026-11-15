//
//  HandoffView.swift
//  NSSB
//

// The payoff.
//
// Somebody steps over out of the dark, leans their cigarette in until the two
// tips touch, the tip catches, and they go back to where they were standing.
// That is the whole feature made visible, and it is the only real animation
// in the app - so it gets the time it needs rather than a fade.
//
// Drawn as an overlay on your own cigarette's frame, which means the
// coordinate space is your own cigarette: the meeting point is your lit end,
// wherever that has burned down to. Your own cigarette is never a copy drawn
// on top - it is the real one, and the reason the ember appears at contact is
// that the break genuinely starts there.

import SwiftUI

struct HandoffView: View {

    /// The cigarette that comes over.
    ///
    /// On your screen when somebody answers your ask, that is them. On their
    /// screen when they answer yours, it is you - the same journey from the
    /// other end, which is why one view does both.
    let visitor: CigDesign

    /// How far through their own cigarette the visitor is, or nil when the
    /// visitor is the one who needs the light. Being lit by somebody almost
    /// finished looks different from being lit by somebody who just started,
    /// and this is where that shows.
    let visitorProgress: Double?

    /// Where the two tips meet: your own lit end, in this view's space.
    let meeting: CGPoint

    /// Which side of the courtyard they were standing on, and how far back.
    /// Taken from the ask id, so somebody who was over to the left comes from
    /// the left.
    let fromLeft: Bool
    let depth: Double

    /// Your own cigarette, which everything is sized against.
    let referenceHeight: CGFloat
    let referenceWidth: CGFloat

    /// The colour of whichever tip is already alight.
    let flame: Color

    /// The tips are touching and the cigarette catches. The caller lights the
    /// break here, which is what puts the ember on screen.
    let onContact: () -> Void

    let onFinished: () -> Void

    @State private var phase: Phase = .away

    /// Five beats, and the whole thing is about two and a third seconds.
    /// Slower than it needs to be to convey the information, which is the
    /// point: this is the one moment in the app worth watching.
    private enum Phase { case away, near, touching, caught, leaving }

    // MARK: Where the visitor is

    /// Out where they were standing, roughly where their cigarette was in the
    /// courtyard: off to one side, higher up the further away they were.
    private var away: CGPoint {
        CGPoint(
            x: fromLeft ? -referenceWidth * 1.9 : referenceWidth * 2.9,
            y: meeting.y + referenceHeight * (0.34 - depth * 0.22)
        )
    }

    /// Leaning in. Clockwise when they come from the left, so the tip tilts
    /// towards your cigarette and the body trails away behind it - the V you
    /// make when you light one off somebody else's.
    private var lean: Double { fromLeft ? 38 : -38 }

    private var angle: Double {
        switch phase {
        case .away, .leaving: return 0
        case .near, .touching, .caught: return lean
        }
    }

    private var height: CGFloat {
        switch phase {
        case .away, .leaving: return referenceHeight * (0.17 + depth * 0.25)
        case .near, .touching, .caught: return referenceHeight * 0.6
        }
    }

    private var visitorLit: Bool {
        visitorProgress != nil || phase == .caught || phase == .leaving
    }

    private var burn: Double { visitorProgress ?? 0 }

    /// Where the visitor's own tip sits inside its frame, as a fraction of
    /// its height. Rotation happens about exactly this point, so the tip
    /// stays put however far the cigarette is leaning.
    private var tipFraction: Double {
        guard visitorLit else { return 0 }
        return visitor.bodyPercentage * min(max(burn, 0), 1)
    }

    /// A hand's width short of contact, held back along the cigarette's own
    /// body so the approach reads as leaning in rather than sliding sideways.
    private var held: CGPoint {
        let radians = lean * .pi / 180
        let gap = referenceHeight * 0.07
        return CGPoint(
            x: meeting.x - sin(radians) * gap,
            y: meeting.y + cos(radians) * gap
        )
    }

    /// A hair past the meeting point, because two cigarettes being lit off
    /// each other overlap. A gap of one pixel reads as not quite touching,
    /// and not quite touching is the whole thing failing.
    private var contact: CGPoint {
        CGPoint(x: meeting.x, y: meeting.y - referenceWidth * 0.06)
    }

    private var tipTarget: CGPoint {
        switch phase {
        case .away, .leaving: return away
        case .near: return held
        case .touching, .caught: return contact
        }
    }

    /// `.position` places a view by its centre, and rotation leaves the
    /// anchor point where it was - so putting the tip somewhere exact is a
    /// matter of offsetting the centre by how far the tip sits from it.
    private var centre: CGPoint {
        CGPoint(
            x: tipTarget.x,
            y: tipTarget.y + (0.5 - tipFraction) * height
        )
    }

    private var visitorOpacity: Double {
        switch phase {
        case .away, .leaving: return 0
        case .near: return 0.92
        case .touching, .caught: return 1
        }
    }

    /// The light at the meeting point. Nothing before they are close, most of
    /// it at the moment the tip catches, and a warmth left over as they go.
    private var bloom: Double {
        switch phase {
        case .away: return 0
        case .near: return 0.12
        case .touching: return 0.65
        case .caught: return 1
        case .leaving: return 0.18
        }
    }

    var body: some View {

        ZStack {

            // Drawn under the visitor, so the two tips sit inside the same
            // pool of light rather than one glowing in front of the other.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [flame.opacity(0.95), flame.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: referenceWidth * 0.9
                    )
                )
                .frame(width: referenceWidth * 1.8, height: referenceWidth * 1.8)
                .scaleEffect(0.35 + bloom * 1.15)
                .opacity(bloom)
                .blur(radius: referenceWidth * 0.18)
                .position(meeting)
                .allowsHitTesting(false)

            DistantCigaretteView(
                design: visitor,
                progress: burn,
                height: height,
                lit: visitorLit
            )
            .rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.5, y: tipFraction))
            .position(centre)
            .opacity(visitorOpacity)
            .allowsHitTesting(false)
        }
        .task {
            await play()
        }
    }

    private func play() async {

        withAnimation(.easeInOut(duration: 0.78)) { phase = .near }
        await pause(0.78)

        withAnimation(.easeOut(duration: 0.24)) { phase = .touching }
        await pause(0.26)

        // The tips are together. This is the moment the cigarette is lit, and
        // the ember that appears now is the real one.
        onContact()

        withAnimation(.easeOut(duration: 0.3)) { phase = .caught }
        await pause(0.6)

        withAnimation(.easeInOut(duration: 0.8)) { phase = .leaving }
        await pause(0.82)

        onFinished()
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
