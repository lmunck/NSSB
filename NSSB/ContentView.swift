//
//  ContentView.swift
//  NSSB
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI


struct ContentView: View {
    
    //@State var progress:Double = 0
    @State var menu:AppMenu = .cigarette
    
    @ObservedObject var keyboardManager = KeyboardManager()
    @ObservedObject var model = WCSessionPhone()
    
    var body: some View {
        
        ZStack {
            
            Color.black
                .ignoresSafeArea()
            
            ScoreView(data: model.data)
                .opacity(keyboardManager.isVisible ? 0 : 1)
                
            HStack {
                
                if menu != .settings {
                    InfoView(menu: $menu, data: model.data)
                        .zIndex(1)
                        .transition(.move(edge: .leading))
                }
                
                CigaretteView(
                    menu: $menu,
                    completedBreak:{ model.completedBreak() },
                    sendUpdate: { model.sendUpdate() },
                    height: UIScreen.main.bounds.height / 2,
                    breakStarted: $model.breakStarted
                )
                 
                if menu != .stats {
                    SettingsView(menu: $menu, costPer20: $model.data.costPer20)
                        .transition(.move(edge: .trailing))
                }
                
            }
            .animation(.easeInOut(duration: 0.2), value: menu)
                
            
            
        }
        .foregroundColor(Color.foregroundInactive)
        
        
    }
    
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
