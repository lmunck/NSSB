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
                .environmentObject(model)
                
        }
    }
}
