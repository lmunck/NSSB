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
                
                
            }
            .foregroundColor(Color.foregroundInactive)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WCSessionPhone())
    }
}


