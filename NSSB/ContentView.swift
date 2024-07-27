//
//  ContentView.swift
//  NSSB
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI


struct ContentView: View {
    
    @State var menu:AppMenu = .cigarette
    
    @EnvironmentObject var model:WCSessionPhone
    
    @State private var offset:CGFloat = 0
    
    var body: some View {
        
        ZStack {
            
            let cigHeight = UIScreen.main.bounds.height * 0.5
            
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                
                HStack {
                    
                    if menu != .info {
                        InfoView(menu: $menu, data: model.data)
                            .zIndex(1)
                            .transition(.move(edge: .leading))
                    }
                    
                    ZStack(alignment: .bottom) {
                        
                        CigaretteView(
                            menu: $menu,
                            completedBreak:{ model.completedBreak() },
                            sendUpdate: { model.sendUpdate() },
                            height: cigHeight,
                            design: model.data.cigDesign,
                            breakStarted: $model.breakStarted
                        )
                        .dragToSelect(menu: $menu)
                        .frame(width: UIScreen.main.bounds.height * 0.1, height: cigHeight)
                        
                        /*if menu == .cigarette {
                            
                            let shareOffset = cigHeight * model.data.cigDesign.widthPercentage * 0.5 + 20
                            
                            ShareCigaretteView(cigarette: model.data.cigDesign)
                                .offset(x: shareOffset, y: 0)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }*/
                        
                    }
                    
                     
                    if menu != .settings {
                        SettingsView(menu: $menu, data: $model.data)
                            .transition(.move(edge: .trailing))
                    }
                    
                }
            
                ScoreView(data: model.data)
                    .frame(height: 80)
            }
            .animation(.easeInOut(duration: 0.2), value: menu)
                
            
            
        }
        .foregroundColor(Color.foregroundInactive)
        
        
    }
    
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WCSessionPhone())
    }
}
