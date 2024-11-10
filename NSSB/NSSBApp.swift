//
//  NSSBApp.swift
//  NSSB
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI

@main
struct NSSBApp: App {
    
    @StateObject private var model = WCSessionPhone()
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                   print("URL received: \(url)")
                    if let design:CigDesign = CigDesign().decodeURL(url) {
                        self.model.data.cigDesign.widthPercentage = 0
                        withAnimation(.easeInOut(duration: 2)) {
                            self.model.data.cigDesign = design
                        }
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        model.load()
                    } else if newPhase == .inactive {
                        model.save()
                    } else if newPhase == .background {
                        model.save()
                    }
                }
                .environmentObject(model)
                
        }
    }
}
