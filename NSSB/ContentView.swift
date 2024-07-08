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
            
            Color.black.edgesIgnoringSafeArea(.all)
            
            // For creating ICON 
            /*let width = UIScreen.main.bounds.width
            
            RadialGradient(gradient: Gradient(colors: [.black, .background]), center: .center, startRadius: width / 100, endRadius: width * 0.8)
                .frame(width: width, height: width, alignment: .center)
                .ignoresSafeArea()*/
            
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
                    design: model.data.cigDesign,
                    breakStarted: $model.breakStarted
                )
                 
                if menu != .stats {
                    SettingsView(menu: $menu, data: $model.data)
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
