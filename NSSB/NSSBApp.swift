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
            //DocumentGroup(newDocument: CigDesignDocument()) { file in
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
               /* .onOpenURL(perform: { url in
                    
                    do {
                        let data = try Data(contentsOf: url)
                        let cigDesign = try CigDesignDocument(data: data)
                        print("Loaded \(cigDesign.cigaretteDesign.title)")
                        self.model.data.cigDesign = cigDesign.cigaretteDesign
                    } catch {
                        print("Error")
                        print(error.localizedDescription)
                    }
                })*/
                .environmentObject(model)
                
            //}
        }
    }
}
