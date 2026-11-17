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
    
    /// The stranger waiting for company whose cigarette is currently tapped.
    @State private var selectedWait:BreakWait? = nil
    
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
                    selectedAsk: $selectedAsk,
                    selectedWait: $selectedWait
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
                        
                        AskForALightView(
                            state: presence.ask,
                            unlit: model.data.breakStarted == nil,
                            othersCount: presence.othersCount,
                            suppressed: presence.company != .idle,
                            ask: askForALight,
                            clear: presence.clearAsk
                        )
                        
                        // No count here, unlike the ask. You are waiting for
                        // somebody else who is also standing out here unlit,
                        // and they are not in the count - so this is the one
                        // social thing in the app that is worth offering in a
                        // completely empty courtyard.
                        WaitForCompanyView(
                            state: presence.company,
                            unlit: model.data.breakStarted == nil,
                            suppressed: presence.ask != .idle,
                            wait: waitForCompany,
                            clear: presence.clearCompany
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
                
                // Somebody waiting. Taking the free chair next to them.
                if let waiting = selectedWait {
                    VStack {
                        WaitDetailView(wait: waiting) {
                            withAnimation(.easeInOut(duration: 0.25)) { selectedWait = nil }
                            waitWith(waiting)
                        }
                        .padding(.top, geo.size.height * 0.08)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
            .onChange(of: presence.waiting) { current in
                // They went in, or somebody else took the chair.
                if let waiting = selectedWait,
                   current.contains(where: { $0.id == waiting.id }) == false {
                    withAnimation(.easeInOut(duration: 0.3)) { selectedWait = nil }
                }
            }
            .onChange(of: selectedAsk) { asking in
                if asking != nil { selectedOther = nil; selectedWait = nil }
            }
            .onChange(of: selectedWait) { waiting in
                if waiting != nil { selectedOther = nil; selectedAsk = nil }
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
    
    /// Asks the courtyard for a light.
    private func askForALight() {
        let design = rolledDesign()
        Task { await presence.askForALight(design: design) }
    }
    
    /// Steps outside and waits for somebody to light up with.
    private func waitForCompany() {
        let design = rolledDesign()
        Task { await presence.waitForCompany(design: design) }
    }
    
    /// Takes the free chair next to somebody already waiting.
    private func waitWith(_ other: BreakWait) {
        let design = rolledDesign()
        Task { await presence.waitWith(other, design: design) }
    }
    
    /// The person you lit up with, standing beside your own cigarette.
    ///
    /// Their burn position is `ownProgress` - not an approximation of it, the
    /// same number. You lit at one instant, so there is nothing to keep in
    /// sync and nothing to ask the network for; the two cigarettes shorten
    /// together and go out together because they were lit together.
    @ViewBuilder
    private func companion(height: CGFloat, width: CGFloat) -> some View {
        
        if let companion = presence.company.companion {
            
            // Whichever side of you they would have been standing on out in
            // the courtyard, so somebody who was over to your left comes to
            // stand on your left.
            let spot = Courtyard.position(for: companion.name)
            let side: CGFloat = spot.x < 0.5 ? -1 : 1
            
            CompanionCigaretteView(
                companion: companion,
                progress: ownProgress,
                height: height
            )
            .offset(x: side * (width * 0.75 + 12), y: 0)
            .transition(.opacity)
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


