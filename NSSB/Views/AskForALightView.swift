//
//  AskForALightView.swift
//  NSSB
//

// Layer 2: the one thing you can actually do to another person in this app.
//
// One line under the cigarette, in the same place and the same voice as the
// count. Nothing here is a notification, a badge or a number that goes up.
// The whole interaction is: you can ask, somebody can answer, and if nobody
// does you light your own - which is what happens most times anyway.

import SwiftUI

struct AskForALightView: View {

    let state: AskState

    /// Only an unlit cigarette has anything to ask for.
    let unlit: Bool

    /// Nil until the courtyard has been looked at once. Asking an empty
    /// courtyard is just an eight-second pause, so the offer is not made.
    let othersCount: Int?

    let ask: () -> Void
    
    /// Called once the line about what happened has been up long enough to
    /// read. Without it the row would go on saying "nobody answered" for the
    /// whole five minutes, and - worse - a finished ask can never be asked
    /// again, so the affordance would never come back.
    let clear: () -> Void

    var body: some View {

        // A fixed row rather than one that appears and disappears: the
        // cigarette must not shuffle up and down the screen because somebody
        // somewhere lit up.
        ZStack {

            switch state {

            case .idle:
                if unlit, let others = othersCount, others > 0 {
                    Text("got a light?")
                        .font(.footnote)
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().stroke(Color.accent.opacity(0.5), lineWidth: 1)
                        )
                        // The same idiom as every other tap in this app.
                        .contentShape(Capsule())
                        .onTapGesture(perform: ask)
                        .transition(.opacity)
                }

            case .asking(let outgoing):
                AskingLineView(ask: outgoing)
                    .transition(.opacity)

            case .lit(let giver):
                line("\(giver.name) is giving you a light")

            case .done(let giver):
                if let giver = giver {
                    line("\(giver.name) gave you a light")
                } else {
                    line("nobody answered - lighting your own")
                }
            }
        }
        .task(id: isDone) {
            guard isDone else { return }
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard Task.isCancelled == false else { return }
            clear()
        }
        .frame(height: 30)
        .animation(.easeInOut(duration: 0.3), value: state)
    }

    private var isDone: Bool {
        if case .done = state { return true }
        return false
    }
    
    private func line(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.gray)
            .transition(.opacity)
    }
}

/// The eight seconds, draining.
///
/// Nobody should have to wonder whether the app is doing something or whether
/// they are being ignored, and "asking..." on its own cannot tell them apart.
/// The bar is also the reassurance that this ends by itself.
private struct AskingLineView: View {

    let ask: BreakAsk

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
        .onAppear {
            // From the document, not from now: a slow round trip eats into
            // the wait rather than extending it, and the bar should say so.
            withAnimation(.linear(duration: max(ask.expiresAt.timeIntervalSinceNow, 0.2))) {
                left = 0
            }
        }
    }
}

/// What you learn by tapping somebody who is asking.
///
/// The same card as a lit stranger's, plus the only button in the app that
/// does something to another person. Their name, their flag, their clock -
/// and no way to reach them before or afterwards.
struct AskDetailView: View {

    let ask: BreakAsk
    let offer: () -> Void

    var body: some View {

        VStack(spacing: 8) {

            VStack(spacing: 2) {

                Text(ask.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    if let flag = ask.flag {
                        Text(flag)
                    }
                    Text("\(ask.localTimeString()) there")
                }
                .font(.footnote)
                .foregroundStyle(.gray)
            }

            Text("give them a light")
                .font(.footnote)
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().stroke(Color.accent.opacity(0.6), lineWidth: 1)
                )
                .contentShape(Capsule())
                .onTapGesture(perform: offer)
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

#Preview {

    var design = CigDesign()
    design.title = "Charcoal Gull"

    let outgoing = BreakAsk.opening(uid: "preview", design: design)
    let giver = AskGiver(answered(design))

    return VStack(spacing: 40) {

        AskForALightView(state: .idle, unlit: true, othersCount: 3, ask: {}, clear: {})
        AskForALightView(state: .asking(outgoing), unlit: true, othersCount: 3, ask: {}, clear: {})

        if let giver = giver {
            AskForALightView(state: .lit(by: giver), unlit: true, othersCount: 3, ask: {}, clear: {})
            AskForALightView(state: .done(givenBy: giver), unlit: false, othersCount: 3, ask: {}, clear: {})
        }

        AskForALightView(state: .done(givenBy: nil), unlit: false, othersCount: 0, ask: {}, clear: {})

        AskDetailView(ask: outgoing, offer: {})
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
}

private func answered(_ design: CigDesign) -> BreakAsk {
    var ask = BreakAsk.opening(uid: "preview", design: design)
    ask.claimed = true
    ask.giverName = "Hollow Lantern"
    ask.giverDesign = design
    ask.giverProgress = 0.6
    return ask
}
