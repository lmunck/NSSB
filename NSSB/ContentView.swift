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
                    referenceHeight: cigHeight,
                    selected: $selectedOther
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
                            height: cigHeight,
                            data: $model.data
                        )
                        .dragToSelect(menu: $menu, progress: $progress, offset: $offset, snapOffset: pageViewWidth)
                        .frame(width: cigWidth, height: cigHeight)
                        //.offset(x: viewOffset, y: 0)
                        .ignoresSafeArea(.keyboard)
                           
                        
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
                
                
            }
            .foregroundColor(Color.foregroundInactive)
            .onChange(of: presence.courtyard) { current in
                // Their cigarette went out, so the card goes with it.
                if let selected = selectedOther,
                   current.contains(where: { $0.id == selected.id }) == false {
                    withAnimation(.easeInOut(duration: 0.3)) { selectedOther = nil }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WCSessionPhone())
    }
}


