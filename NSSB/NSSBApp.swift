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
            
            // Receive custom cigarette design from other user
                .onOpenURL { url in
                   print("URL received: \(url)")
                    if let design:CigDesign = CigDesign().decodeURL(url) {
                        self.model.data.cigDesign.widthPercentage = 0
                        withAnimation(.easeInOut(duration: 2)) {
                            self.model.data.cigDesign = design
                        }
                    }
                }
            
            // Save status if app moves to background
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        model.load()
                    } else if newPhase == .inactive {
                        model.save()
                    } else if newPhase == .background {
                        model.save()
                    }
                }
            
            // Add model to environment for entire app
                .environmentObject(model)
                
        }
    }
}
