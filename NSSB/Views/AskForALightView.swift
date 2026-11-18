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

// The offer itself used to live here, beside a second one for waiting. Both
// are now a single row - see ReachOutView - because they were one intention
// wearing two buttons. What is left in this file is the other end of the
// exchange: the card you get by tapping somebody who is asking, and the only
// button in the app that does something to another person.

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

    return VStack(spacing: 40) {
        AskDetailView(ask: outgoing, offer: {})
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
}
