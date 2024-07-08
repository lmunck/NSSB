//
//  CigaretteView.swift
//  NSSB
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI
import UserNotifications



struct CigaretteView: View {
    
    // Parent
    @Binding var menu:AppMenu
    var completedBreak : () -> Void
    var sendUpdate: () -> Void
    
    // Cigarette design
    var height:CGFloat
    var design:CigDesign
    
    // Progress
    @Binding var breakStarted:Date?
    @State private var breakProgress:Double = 0
    let smokingTime:Double = 7 * 60 // Seconds
    let smokingTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        
        let glowHeight:CGFloat = breakStarted != nil ? self.height * design.glowPercentage : 0
        let bodyHeight:CGFloat = bodyHeight(height: self.height, progress: breakProgress, glowHeight: glowHeight)
        let filterHeight:CGFloat = self.height * 0.25
        
        let width = self.height * design.widthPercentage
        
        return HStack {
            
            VStack(spacing: 0) {
                
                Color.clear
                    .onReceive(smokingTimer) { _ in
                        updateProgress()
                    }
                
                if breakStarted != nil {
                    
                    CigaretteAshView(design: design, height: glowHeight, width: width)
                    
                }
                
                LinearGradient(gradient: Gradient(colors: design.bodyArray), startPoint: .leading, endPoint: .trailing)
                    .frame(width: width, height: bodyHeight)
                
                ZStack {
                    
                    LinearGradient(gradient: Gradient(colors: design.filterArray), startPoint: .leading, endPoint: .trailing)
                    
                    CigaretteGlowDots(height: filterHeight, width: width, color: design.filterDots, animated: false)
                    
                }
                    .frame(width: width, height: filterHeight)
                
            }
            .frame(width: width, height: self.height)
            .onTapGesture {
                toggleSmoking()
            }
            .onChange(of: breakStarted) { status in
                receivedUpdate(status)
            }
            
            
            //.animation(.easeOut(duration: 0.3), value: smokingStarted)
            .animation(.linear(duration: breakStarted != nil ? 1 : 0.3), value: breakProgress)
            
        }
        .padding(self.height * 0.05)
        .background(
            design.background.blur(radius: self.height * 0.15)
        )
        
    }
    
    // Smoke update update
    func toggleSmoking() {
        if menu != .cigarette {
            self.menu = .cigarette
        } else {
            
            if breakStarted == nil {
                breakStarted = Date.now
            } else {
                breakStarted = nil
            }
            sendUpdate()
            
        }
    }
    
    // Received update
    func receivedUpdate(_ status: Date?) {
        
        // Break started
        if status != nil {
            
            setCigaretteStartedReminder(smokingTime)
            
        // Break finished
        } else {
            removeCigaretteStartedReminder()
            breakProgress = 0
            
        }
    }
    
    
    func updateProgress() {
        
        // Check that smoking is running
        if let breakStarted = self.breakStarted {
            
            // Check how much time has passed since it started
            let timeActual:Double = -breakStarted.timeIntervalSinceNow
            
            // Check that the time is still less than the full time for a cigarette
            if timeActual < smokingTime {
                
                // Update progress
                breakProgress = timeActual / smokingTime
                
                
            } else {
                
                
                // Success vibration
                #if os(iOS)
                let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                #endif
                
                #if os(watchOS)
                WKInterfaceDevice.current().play(.success)
                #endif
                
                // Quit smoking
                self.breakStarted = nil
                
                // Update score
                completedBreak()
                
                
            }
        }
    }
    
    func bodyHeight(height: CGFloat, progress: Double, glowHeight: CGFloat) -> CGFloat {
        
        let fullHeight:CGFloat = design.bodyPercentage * height - glowHeight
        
        var bodyHeight = fullHeight - fullHeight * progress
        
        if bodyHeight < 0 { bodyHeight = 0 }
        
        return bodyHeight
    }
    
    func setCigaretteStartedReminder(_ timeToSmoke:Double) {
        
        let interval:TimeInterval = timeToSmoke
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        addStopNotification(at: trigger)
        
        func addStopNotification(at trigger: UNNotificationTrigger) {
            
            let content = UNMutableNotificationContent()
            content.title = "Non-smoking break completed!"
            content.subtitle = "Time to get back to the grind."
            content.sound = UNNotificationSound.default

            // choose a random identifier
            let request = UNNotificationRequest(identifier: "smokeBreakOngoing", content: content, trigger: trigger)

            // add our notification request
            UNUserNotificationCenter.current().add(request)
            
        }
    }
    
    func removeCigaretteStartedReminder() {
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["smokeBreakOngoing"])
    }
    
}

struct CigaretteView_Previews: PreviewProvider {
    
    
    static var previews: some View {
        CigaretteView(menu: .constant(.cigarette), completedBreak: {}, sendUpdate: {}, height: 400, design: CigDesign.standard, breakStarted: .constant(Date.now))
            
    }
}



