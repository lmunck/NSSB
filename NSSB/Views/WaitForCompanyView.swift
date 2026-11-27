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
                        // Tappable text is still only text to VoiceOver.
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Asks the courtyard for a light")
                        .transition(.opacity)
                }

            case .reaching(let until):
                ReachingLineView(until: until)
                    .transition(.opacity)

            case .lit(let giver):
                line("\(giver.name) is giving you a light")

            case .answered(let giver):
                line("\(giver.name) gave you a light")

            case .together:

                // Nothing. Their names are on their own cigarettes now,
                // with their flag and where they are in their own day, and
                // this line was the same three facts written again at the
                // bottom of the screen - where you had to match each one
                // back up to a cigarette by guesswork.
                EmptyView()

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
        ReachOutView(state: .together([together]), unlit: false, reach: {}, clear: {})
        ReachOutView(state: .together([together, lighter]), unlit: false, reach: {}, clear: {})
        ReachOutView(state: .alone, unlit: true, reach: {}, clear: {})
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
