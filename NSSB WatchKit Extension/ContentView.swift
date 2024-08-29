//
//  ContentView.swift
//  NSSB WatchKit Extension
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI

struct ContentView: View {
    
    @State private var menu:AppMenu = .cigarette
    @ObservedObject var model = WCSessionWatch()
    
    var body: some View {
        
        GeometryReader { geo in
            
            ZStack {
                
                Color.black.edgesIgnoringSafeArea(.all)
                
                CigaretteView(
                    menu: $menu,
                    height: geo.size.height,
                    data: $model.data
                )
                
                ScoreView(data: model.data)
                
                if #available(watchOS 10.0, *) {
                    MenuView(data: $model.data)
                }
                
            }
            .foregroundStyle(Color.foregroundInactive)
            
        }
    }
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
