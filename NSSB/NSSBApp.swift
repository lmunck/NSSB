//
//  NSSBApp.swift
//  NSSB
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct NSSBApp: App {
    
    @StateObject private var model = WCSessionPhone()
    @StateObject private var presence = PresenceRepository()
    
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        // Only when a project has actually been configured - see
        // firebase/README.md. Without the plist the app runs exactly as
        // before, on the simulated presence service.
        #if canImport(FirebaseCore)
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        #endif
    }
    
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
            
            // Anonymous sign-in, then publish a break that was already
            // running when the app launched - at its real start time, so it
            // comes back at its true position in the burn.
                .task {
                    await presence.start()
                    if let startedAt = model.data.breakStarted, startedAt.breakIsActive {
                        await presence.breakStarted(at: startedAt, design: model.data.cigDesign)
                    }
                }
            
            // A break began or ended. Everything ends when the cigarette
            // does: the document goes and the listener detaches.
                .onChange(of: model.data.breakStarted) { newValue in
                    Task {
                        if let startedAt = newValue, startedAt.breakIsActive {
                            await presence.breakStarted(at: startedAt, design: model.data.cigDesign)
                        } else {
                            await presence.breakEnded()
                        }
                    }
                }
            
            // Add model to environment for entire app
                .environmentObject(model)
                .environmentObject(presence)
                
        }
    }
}
