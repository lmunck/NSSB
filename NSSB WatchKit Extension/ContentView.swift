//
//  ContentView.swift
//  NSSB WatchKit Extension
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI

struct ContentView: View {
    
    @State private var menu:AppMenu = .cigarette
    @StateObject private var model = WCSessionWatch()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        
        GeometryReader { geo in
            
            ZStack {
                
                Color.black.edgesIgnoringSafeArea(.all)
                
                CigaretteView(
                    menu: $menu,
                    height: geo.size.height,
                    data: $model.data
                )
                
                // Whoever is out here with you, standing beside your own
                // cigarette. Nobody, unless the phone has said otherwise
                // and your own break is still running.
                CompanyView(
                    company: model.company,
                    mine: model.data.cigDesign,
                    yourBreak: model.data.breakStarted,
                    height: geo.size.height
                )
                
                ScoreView(breaks: model.data.breaks, costPer20: model.data.costPer20)
                
                MenuView(data: $model.data)
                
                /*Image(systemName: "circle.fill")
                    .foregroundStyle(model.connected ? Color.green : Color.red)
                    .frame(maxWidth: .infinity, maxHeight:.infinity, alignment: .topLeading)*/
            }
            .foregroundStyle(Color.foregroundInactive)
            
        }
        // Keep the local save in sync when the app leaves the screen
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                model.save()
            }
        }
    }
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
