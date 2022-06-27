//
//  NSSBApp.swift
//  NSSB WatchKit Extension
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI

@main
struct NSSBApp: App {
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView().navigationBarHidden(true)
            }
        }

        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}
