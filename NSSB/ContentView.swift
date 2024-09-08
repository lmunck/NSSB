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
        
        GeometryReader { geo in
            
            ZStack {
                
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
                
                Color.black.edgesIgnoringSafeArea(.all)
                
                
                
                VStack(spacing: 10) {
                    
                    MenuView(menu: $menu)
                    
                    HStack(spacing: 0) {
                        
                        InfoView(menu: $menu, data: model.data)
                            .opacity(infoOpacity)
                            .offset(x: self.offset - (1 - infoOpacity) * cigWidth, y: 0)
                            .frame(width: viewWidth)
                        
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
                            .offset(x: self.offset + (1 - settingsOpacity) * cigWidth, y: 0)
                        
                    }
                    .frame(width: geo.size.width)
                
                    ScoreView(data: model.data)
                }
                .animation(.easeOut(duration: 0.2), value: menu)
                
                
                Image(systemName: "circle.fill")
                    .foregroundStyle(model.connected ? Color.green : Color.red)
                    .frame(maxWidth: .infinity, maxHeight:.infinity, alignment: .topLeading)
                
                
                
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


