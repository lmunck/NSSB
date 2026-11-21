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
                    // Whoever is over here beside you is not standing out
                    // there as well. They were drawn in both places at
                    // once: their lit cigarette kept its spot in the
                    // courtyard while a copy of it came over and stayed.
                    others: presence.courtyard.filter { nearby.contains($0.name) == false },
                    echoes: presence.echoes.filter { nearby.contains($0.name) == false },
                    asks: presence.offers.filter { $0.id != presence.giving?.id },
                    waits: presence.waiting,
                    referenceHeight: cigHeight,
                    taken: taken,
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
                        
                        // Whoever is out here with you: the one walking
                        // over right now and the ones already standing,
                        // in one overlay because they are one list of
                        // people. There used to be two - a handoff drawn
                        // over the top of a separate companion - and the
                        // moment one handed over to the other was the
                        // moment the cigarette blinked out and jumped.
                        .overlay {
                            BesideYouView(
                                people: people,
                                mine: model.data.cigDesign,
                                height: cigHeight,
                                yourProgress: ownProgress,
                                courtyard: geo.size
                            )
                            .opacity(cigOpacity)
                        }
                        
                        
                        SettingsView(menu: $menu, data: $model.data)
                            .opacity(settingsOpacity)
                            .frame(width: viewWidth)
                        
                        // offset when transparent
                            .offset(x: self.offset + (1 - settingsOpacity) * cigWidth, y: 0)
                        
                    }
                    .frame(width: geo.size.width)
                    
                    // There was a line here saying how many other people
                    // were out. It is gone, and so is the number: when
                    // nobody was there it said so, which is telling
                    // somebody there is nothing to tell them, and when
                    // somebody was there it put a figure under a courtyard
                    // you could already see. The lit cigarettes behind your
                    // own are the count.
                    
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
            // Named so that somebody walking out of the courtyard and over
            // to your hand can work out where they were standing. The two
            // live in different frames, and the walk between them is the
            // whole feature.
            .coordinateSpace(name: Courtyard.space)
            .foregroundColor(Color.foregroundInactive)
            .onChange(of: presence.courtyard) { _, current in
                // Their cigarette went out, so the card goes with it.
                if let selected = selectedOther,
                   current.contains(where: { $0.id == selected.id }) == false {
                    withAnimation(.easeInOut(duration: 0.3)) { selectedOther = nil }
                }
            }
            .onChange(of: presence.company) { _, state in
                
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
            .onChange(of: presence.ask) { _, state in
                
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
    
    /// Which sides of you are already taken.
    ///
    /// Read by the courtyard as well as by the overlay, so the two agree
    /// about where somebody is standing - which is what lets a walk start
    /// exactly where the courtyard drew them.
    private var taken: Set<CompanionSide> {
        Set(presence.company.companions.map(\.side))
    }
    
    /// Whoever is over here beside you rather than out in the courtyard.
    ///
    /// By name, because that is all a courtyard document and a companion
    /// have in common - they come from different collections. Everything
    /// else here goes by the document.
    private var nearby: Set<String> {
        Set(people.map(\.companion.name))
    }
    
    /// Everybody who is out here with you: the one walking over right now,
    /// and the ones already standing there.
    ///
    /// One list, keyed by name, and that is the whole of the fix to an
    /// animation that used to be three. A handoff and a companion were two
    /// different views of the same person, so when the first finished and
    /// the second appeared, SwiftUI was quite correctly told that one
    /// cigarette had left and a different one had arrived - and drew exactly
    /// that. Here the person stays the same person; only their `handoff`
    /// goes nil, and the view that is already on screen carries on moving.
    private var people: [Visitor] {
        
        var out: [Visitor] = []
        
        if case .lit(let giver) = presence.ask {
            
            // Somebody is lighting you. Your cigarette is still unlit, so
            // the tip that catches is your own.
            var companion = Companion(giver: giver, metAt: .now)
            companion.side = presence.company.sideFor(giver.name)
            
            out.append(visitor(companion, handoff: Visitor.Handoff(
                theirsCatches: false,
                onContact: {
                    litByStranger = .now
                    knock()
                    model.tellWatchYouWereLit()
                },
                onSettled: { presence.handoffFinished() }
            )))
            
        } else if let asking = presence.giving {
            
            // You are lighting somebody. Your own tip has burned down to
            // wherever it has, and that is where they lean in to.
            var companion = Companion(lit: asking, at: .now)
            companion.side = presence.company.sideFor(asking.name)
            
            out.append(visitor(companion, handoff: Visitor.Handoff(
                theirsCatches: true,
                onContact: { knock() },
                onSettled: { presence.offerFinished() }
            )))
        }
        
        // Up to two, one on each side. Whoever got here first kept the side
        // they would have been standing on in the courtyard; the second took
        // what was left. Neither moves when the other finishes.
        for companion in presence.company.companions
        where out.contains(where: { $0.id == companion.id }) == false {
            out.append(visitor(companion, handoff: nil))
        }
        
        // One order, always, so nobody is torn down and rebuilt for having
        // moved along the list.
        return out.sorted { $0.id < $1.id }
    }
    
    /// Somebody, the spot in the courtyard they came from, and whether
    /// there is anywhere for them to stand when they get here.
    private func visitor(_ companion: Companion, handoff: Visitor.Handoff?) -> Visitor {
        
        // Somebody already standing there is not dodging anybody, least of
        // all themselves. Somebody walking over has to start from exactly
        // where the courtyard drew them, which means dodging what the
        // courtyard was dodging.
        let avoiding = handoff == nil ? taken.subtracting([companion.side]) : taken
        let spot = Courtyard.position(for: companion.name, avoiding: avoiding)
        
        // The same two rules the repository uses when it decides whether to
        // keep them, asked here so the walk ends where they actually end up.
        // They used to disagree: the view walked them to a place beside you
        // and the repository quietly declined to put them there, so they
        // arrived on top of somebody and then vanished.
        let room = handoff == nil
            || (presence.company.isFull == false && companion.hasGone() == false)
        
        let home = Courtyard.position(for: companion.name)
        
        return Visitor(
            companion: companion,
            from: CGPoint(x: spot.x, y: spot.y),
            depth: spot.depth,
            handoff: handoff,
            goes: room ? .besideYou : .backOutside(CGPoint(x: home.x, y: home.y))
        )
    }
    
    /// Your own burn position, without ExtDate's debug print on every frame.
    private var ownProgress: Double {
        guard let startedAt = model.data.breakStarted else { return 0 }
        return min(max(startedAt.elapsedTime / Date.breakLength, 0), 1)
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


