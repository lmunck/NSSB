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
    @State private var selectedAsk:BreakAsk? = nil
    
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
                    referenceHeight: cigHeight,
                    selected: $selectedOther,
                    selectedAsk: $selectedAsk
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
                    
                    // Got a light?
                    AskForALightView(
                        state: presence.ask,
                        unlit: model.data.breakStarted == nil,
                        othersCount: presence.othersCount,
                        ask: askForALight,
                        clear: presence.clearAsk
                    )
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
                
                // Somebody asking. The same card, with the one button in the
                // app that does something to another person.
                if let asking = selectedAsk {
                    VStack {
                        AskDetailView(ask: asking) {
                            withAnimation(.easeInOut(duration: 0.25)) { selectedAsk = nil }
                            Task { await presence.offerLight(to: asking) }
                        }
                        .padding(.top, geo.size.height * 0.08)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                
            }
            .foregroundColor(Color.foregroundInactive)
            .onChange(of: presence.courtyard) { current in
                // Their cigarette went out, so the card goes with it.
                if let selected = selectedOther,
                   current.contains(where: { $0.id == selected.id }) == false {
                    withAnimation(.easeInOut(duration: 0.3)) { selectedOther = nil }
                }
            }
            .onChange(of: presence.offers) { current in
                // Their eight seconds ran out, or somebody else answered.
                if let asking = selectedAsk,
                   current.contains(where: { $0.id == asking.id }) == false {
                    withAnimation(.easeInOut(duration: 0.3)) { selectedAsk = nil }
                }
            }
            .onChange(of: selectedAsk) { asking in
                if asking != nil { selectedOther = nil }
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
    
    /// Asks the courtyard.
    ///
    /// The name is rolled first and written back, so the cigarette standing
    /// in everyone else's courtyard asking and the cigarette that gets
    /// published afterwards are the same cigarette with the same name.
    private func askForALight() {
        
        var temp = model.data
        if temp.cigDesign.title.isEmpty {
            temp.cigDesign.title = randomCigaretteName()
        }
        model.data = temp
        
        let design = temp.cigDesign
        Task { await presence.askForALight(design: design) }
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


