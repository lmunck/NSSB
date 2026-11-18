//
//  ContentView.swift
//  NSSB
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI


struct ContentView: View {
    
    @State var menu:AppMenu = .cigarette
    @State private var progress:Double = 0
    @State private var offset:CGFloat = .zero
    
    @EnvironmentObject var model:WCSessionPhone
    @EnvironmentObject var presence:PresenceRepository
    
    /// The stranger whose cigarette is currently tapped, if any.
    @State private var selectedOther:BreakPresence? = nil
    
    /// The stranger asking for a light whose cigarette is currently tapped.
    /// Separate from the above, because this card has a button on it.
    
    /// The stranger waiting for company whose cigarette is currently tapped.
    
    /// Set at the moment the two tips touch, which is what lights the
    /// cigarette. Nothing else writes it.
    @State private var litByStranger:Date? = nil
    
    var body: some View {
        
        // read screen geometry, size, scale, etc.
        GeometryReader { geo in
            
            ZStack {
                
                // View geometry
                let cigHeight = geo.size.height * 0.7
                let cigWidth = geo.size.width * 0.2
                
                let viewWidth = geo.size.width * 0.8
                let pageViewWidth = geo.size.width * 0.4
                
                var infoOpacity:CGFloat {
                    let infoOpacity = self.offset/pageViewWidth
                    return min(max(infoOpacity, 0), 1)
                }
                
                var settingsOpacity:CGFloat {
                    let setOpacity = -self.offset/pageViewWidth
                    return min(max(setOpacity, 0), 1)
                }
                
                var cigOpacity:CGFloat {
                    return 1 - max(settingsOpacity, infoOpacity)
                }
                
                // Background view
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Everyone else who is out here, standing behind you. Empty
                // unless a break is running, because the listener is only
                // attached for the length of a cigarette.
                CourtyardView(
                    others: presence.courtyard,
                    echoes: presence.echoes,
                    // Whoever you are in the middle of lighting is not
                    // standing out there any more - they are over here, in
                    // the handoff, and drawing them twice would break it.
                    asks: presence.offers.filter { $0.id != presence.giving?.id },
                    waits: presence.waiting,
                    referenceHeight: cigHeight,
                    selected: $selectedOther,
                    offer: { asking in Task { await presence.offerLight(to: asking) } },
                    join: waitWith
                )
                .opacity(cigOpacity)
                .allowsHitTesting(menu == .cigarette)
                
                // Main view
                VStack(spacing: 10) {
                    
                    // Top menu
                    MenuView(menu: $menu)
                    
                    // Center view
                    HStack(spacing: 0) {
                        
                        
                        InfoView(menu: $menu, data: model.data)
                            .opacity(infoOpacity)
                            .frame(width: viewWidth)
                        
                        // offset when transparent
                            .offset(x: self.offset - (1 - infoOpacity) * cigWidth, y: 0)
                        
                        CigaretteView(
                            menu: $menu,
                            cigOpacity: cigOpacity,
                            litByStranger: litByStranger,
                            height: cigHeight,
                            data: $model.data
                        )
                        .dragToSelect(menu: $menu, progress: $progress, offset: $offset, snapOffset: pageViewWidth)
                        .frame(width: cigWidth, height: cigHeight)
                        //.offset(x: viewOffset, y: 0)
                        .ignoresSafeArea(.keyboard)
                        
                        // The handoff is drawn over your own cigarette's
                        // frame, so the meeting point is your own lit end
                        // wherever it has burned down to.
                        .overlay {
                            handoff(height: cigHeight, width: cigWidth)
                                .opacity(cigOpacity)
                        }
                        
                        // Whoever you lit up with, standing next to you for
                        // the whole five minutes. Drawn in the same frame as
                        // your own cigarette and at the same height, because
                        // they are not across the courtyard - they are here,
                        // burning down at exactly your pace.
                        .overlay {
                            companion(height: cigHeight, width: cigWidth)
                                .opacity(cigOpacity)
                        }
                           
                        
                        SettingsView(menu: $menu, data: $model.data)
                            .opacity(settingsOpacity)
                            .frame(width: viewWidth)
                        
                        // offset when transparent
                            .offset(x: self.offset + (1 - settingsOpacity) * cigWidth, y: 0)
                        
                    }
                    .frame(width: geo.size.width)
                    
                    // Who else is out here. Fades with the cigarette, so it
                    // stays out of the way while a panel is open.
                    CourtyardCountView()
                        .opacity(cigOpacity)
                    
                    // The two things you can do before lighting up, in one
                    // row: ask somebody already out there for a light, or
                    // wait for somebody to start with. Side by side while
                    // both are available, and whichever one is happening
                    // takes the row to itself.
                    // Spacing lives on the capsules rather than here, so a
                    // row holding only one of the two offers still centres
                    // it exactly. An empty view is still a view, and an
                    // HStack would otherwise leave half a gap behind it.
                    HStack(spacing: 0) {
                        
                        ReachOutView(
                            state: presence.outreach,
                            unlit: model.data.breakStarted == nil,
                            reach: reachOut,
                            clear: {
                                // Both machines, because either of them can
                                // be the one holding the line that is up.
                                presence.clearAsk()
                                presence.clearCompany()
                            }
                        )
                    }
                    .opacity(cigOpacity)
                    .allowsHitTesting(menu == .cigarette)
                
                    // Score view
                    ScoreView(breaks: model.data.breaks, costPer20: model.data.costPer20)
                }
                .animation(.easeOut(duration: 0.2), value: menu)
                
                // Who you just tapped. Sits above everything, dismissed by
                // tapping the same cigarette again.
                if let selected = selectedOther {
                    VStack {
                        // Above the cigarette, in the empty part of the
                        // screen. Over it, the card covered the share button
                        // and the name, and the cigarette showed through.
                        CourtyardDetailView(presence: selected)
                            .padding(.top, geo.size.height * 0.1)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
                }
                
                // There were two cards here, each with a button on it, for
                // the two people you can do something for. Both are gone.
                // Aiming at somebody who is asking is already the decision -
                // a card that asks whether you meant it is a click charged
                // for nothing, and these gestures are meant to cost nothing.
            }
            .foregroundColor(Color.foregroundInactive)
            .onChange(of: presence.courtyard) { current in
                // Their cigarette went out, so the card goes with it.
                if let selected = selectedOther,
                   current.contains(where: { $0.id == selected.id }) == false {
                    withAnimation(.easeInOut(duration: 0.3)) { selectedOther = nil }
                }
            }
            .onChange(of: presence.company) { state in
                
                // The wait is over, one way or the other, and either way the
                // cigarette gets lit - the same contract as the ask.
                //
                // Somebody came out: light at the instant you were paired,
                // not at now. That one value is the whole feature; using
                // `now` here would start your break a round trip after
                // theirs, and the two cigarettes would not go out together.
                //
                // Nobody came: light it because that is what the line of
                // text says is happening, and because waiting must never
                // leave you worse off than simply tapping would have.
                guard model.data.breakStarted == nil else { return }
                
                switch state {
                case .together(_, let since):
                    litByStranger = since
                    knock()
                case .alone:
                    litByStranger = .now
                default:
                    break
                }
            }
            .onChange(of: presence.ask) { state in
                
                // The ask is over, one way or the other, and either way the
                // cigarette gets lit.
                //
                // Somebody answered: light it here if the handoff never got
                // to - the app backgrounded mid-animation, say. The gift was
                // still given and losing it quietly would be the worst
                // outcome of the whole feature.
                //
                // Nobody answered: light it because that is what the line of
                // text says is happening, and because asking must never leave
                // you worse off than simply tapping would have.
                if case .done = state, model.data.breakStarted == nil {
                    litByStranger = .now
                }
            }
        }
    }
}

extension ContentView {
    
    /// The design this device is about to stand in a courtyard with.
    ///
    /// The name is rolled here and written back, so the cigarette other
    /// people see standing out there and the cigarette that gets published
    /// when it lights are the same cigarette with the same name.
    private func rolledDesign() -> CigDesign {
        
        var temp = model.data
        if temp.cigDesign.title.isEmpty {
            temp.cigDesign.title = randomCigaretteName()
        }
        model.data = temp
        
        return temp.cigDesign
    }
    
    /// Asks the courtyard, one tap.
    ///
    /// Underneath this puts the question to everybody already lit and stands
    /// you out there unlit for anybody else at the same time. Whoever reaches
    /// you first is who you end up smoking with, and you never had to decide
    /// which kind of company you were hoping for.
    private func reachOut() {
        let design = rolledDesign()
        Task { await presence.reachOut(design: design) }
    }
    
    /// Takes the free chair next to somebody already waiting.
    private func waitWith(_ other: BreakWait) {
        let design = rolledDesign()
        Task { await presence.waitWith(other, design: design) }
    }
    
    /// Whoever is out here with you, standing beside your own cigarette.
    ///
    /// Two people who lit together burn at the same position and go out on
    /// the same second, with nothing to keep in sync and nothing to ask the
    /// network for - they were lit at one instant. Somebody who stopped to
    /// light you was already burning, so theirs runs ahead of yours and goes
    /// out first, and the view draws that from their own ignition instant
    /// rather than borrowing yours.
    @ViewBuilder
    private func companion(height: CGFloat, width: CGFloat) -> some View {
        
        // Up to two, one on each side. Whoever got here first kept the side
        // they would have been standing on in the courtyard; the second took
        // what was left. Neither moves when the other finishes.
        ForEach(presence.company.companions, id: \.name) { companion in

            let side: CGFloat = companion.side == .left ? -1 : 1

            // Measured from the two cigarettes rather than from the layout
            // frame, and clear of what already hangs beside your own: the
            // share button to the right of it, the title to the left. The
            // old offset was a fraction of the frame width and stood them
            // straight through the share button.
            let mine = height * model.data.cigDesign.widthPercentage
            let theirs = height * companion.design.widthPercentage

            let rest = mine / 2 + 52 + theirs / 2

            CompanionCigaretteView(
                companion: companion,
                height: height,
                mirrored: side < 0,
                arrival: companion.metAtYourTip(whenYouLitAt: presence.company.litAt ?? .now)
                    ? .fromYourTip : .fromTheDark,
                restingOffset: rest
            )
            .offset(x: side * rest, y: 0)
            // No transition here: the view walks itself in, and a crossfade
            // laid over that read as a second, competing arrival.
            .allowsHitTesting(false)
        }
    }
    
    /// Your own burn position, without ExtDate's debug print on every frame.
    private var ownProgress: Double {
        guard let startedAt = model.data.breakStarted else { return 0 }
        return min(max(startedAt.elapsedTime / Date.breakLength, 0), 1)
    }
    
    /// Whichever side of the handoff this device is on, if either.
    ///
    /// Both sides see the same thing from opposite ends: somebody comes over,
    /// the tips touch, a cigarette catches. Receiving it, the visitor is the
    /// stranger and the tip that catches is your own. Giving it, the visitor
    /// is the stranger and the tip that catches is theirs.
    @ViewBuilder
    private func handoff(height: CGFloat, width: CGFloat) -> some View {
        
        if case .lit(let giver) = presence.ask {
            
            // Somebody is lighting you. Your cigarette is still unlit, so the
            // meeting point is its very tip.
            let spot = Courtyard.position(for: giver.name)
            
            HandoffView(
                visitor: giver.design,
                visitorProgress: giver.progress,
                meeting: CGPoint(x: width / 2, y: 0),
                fromLeft: spot.x < 0.5,
                depth: spot.depth,
                referenceHeight: height,
                referenceWidth: height * giver.design.widthPercentage,
                flame: giver.design.glow,
                onContact: {
                    litByStranger = .now
                    knock()
                    model.tellWatchYouWereLit()
                },
                onFinished: { presence.handoffFinished() }
            )
            
        } else if let asking = presence.giving {
            
            // You are lighting somebody. Your own tip has burned down to
            // wherever it has, and that is where they lean in to.
            let spot = Courtyard.position(for: asking.id)
            let design = model.data.cigDesign
            
            HandoffView(
                visitor: asking.design,
                visitorProgress: nil,
                meeting: CGPoint(
                    x: width / 2,
                    y: design.tipOffset(height: height, progress: ownProgress)
                ),
                fromLeft: spot.x < 0.5,
                depth: spot.depth,
                referenceHeight: height,
                referenceWidth: height * design.widthPercentage,
                flame: design.glow,
                onContact: { knock() },
                onFinished: { presence.offerFinished() }
            )
        }
    }
    
    /// The click of a lighter. Soft, once, at the moment of contact.
    private func knock() {
        let feedback = UIImpactFeedbackGenerator(style: .soft)
        feedback.prepare()
        feedback.impactOccurred(intensity: 0.7)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WCSessionPhone())
    }
}


