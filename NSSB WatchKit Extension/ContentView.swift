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
                    completedBreak: { model.completedBreak() },
                    sendUpdate: { model.sendUpdate() } ,
                    height: geo.size.height,
                    breakStarted: $model.breakStarted)
                
                HStack {
                    
                    VStack(spacing: 0) {
                        Text("Today").font(.footnote)
                        
                        Text("\(model.todayBreaks)").font(.largeTitle)
                    }
                    
                    Spacer()
                    
                    
                    VStack(spacing: 0) {
                        Text("All time").font(.footnote)
                        
                        Text("\(model.totalBreaks)").font(.largeTitle)
                    }
                }
            }
            .foregroundColor(Color.white.opacity(0.5))
        }
    }
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
