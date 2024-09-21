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
                
                ScoreView(breaks: model.data.breaks, costPer20: model.data.costPer20)
                
                if #available(watchOS 10.0, *) {
                    MenuView(data: $model.data)
                }
                
                /*Image(systemName: "circle.fill")
                    .foregroundStyle(model.connected ? Color.green : Color.red)
                    .frame(maxWidth: .infinity, maxHeight:.infinity, alignment: .topLeading)*/
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
