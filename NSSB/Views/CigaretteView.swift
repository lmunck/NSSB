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
    var height:CGFloat = 100
    let glowPercentage:Double = 0.1
    let bodyPercentage:Double = 0.75
    let filterPercentage:Double = 0.25
    
    let backgroundGlowIdle:Color = Color.blue
    
    // Progress
    @Binding var breakStarted:Date?
    @State private var breakProgress:Double = 0
    let smokingTime:Double = 7 * 60 // Seconds
    let smokingTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        
        let glowHeight:     CGFloat = breakStarted != nil ? height * glowPercentage : 0
        let bodyHeight:     CGFloat = bodyHeight(height: height, progress: breakProgress, glowHeight: glowHeight)
        let filterHeight:   CGFloat = height * 0.25
        
        let width = height * 0.1
        
        return HStack {
            
            
            VStack(spacing: 0) {
                
                Color.clear
                    .onReceive(smokingTimer) { _ in
                        updateProgress()
                    }
                
                CigaretteElementView(element: CigaretteElement.glow)
                    .shadow(color: .red, radius: 30)
                    .shadow(color: .orange.opacity(0.5), radius: 5)
                    .overlay(CigaretteGlowDots(height: glowHeight, width: width, color: .red, animated: true))
                    .frame(height: glowHeight)
                
                CigaretteElementView(element: CigaretteElement.body)
                    .frame(height: bodyHeight)
                
                CigaretteElementView(element: CigaretteElement.filter)
                    .frame(height: filterHeight)
                    .overlay(CigaretteGlowDots(height: filterHeight, width: width, color: CigaretteElement.filter.colors.0, animated: false))
                
            }
            .frame(width: width, height: height)
            .onTapGesture {
                toggleSmoking()
            }
            .onChange(of: breakStarted) { status in
                receivedUpdate(status)
            }
            
            
            //.animation(.easeOut(duration: 0.3), value: smokingStarted)
            .animation(.linear(duration: breakStarted != nil ? 1 : 0.3), value: breakProgress)
            
        }
        .padding(15)
        .background(
            Color.accent.blur(radius: height * 0.1)
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
        
        let fullHeight:CGFloat = bodyPercentage * height - glowHeight
        
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
        CigaretteView(menu: .constant(.cigarette), completedBreak: {}, sendUpdate: {}, breakStarted: .constant(Date.now))
    }
}


// MARK: Cigarette

enum CigaretteElement {
    case filter, body, glow
    
    var colors: (Color, Color) {
        switch self {
        case .filter: return (
            Color(red: 1.0, green: 0.8, blue: 0.5),
            Color(red: 0.6, green: 0.4, blue: 0.1)
            )
        case .body: return (
            Color(red: 1.0, green: 1.0, blue: 1.0),
            Color(red: 0.6, green: 0.6, blue: 0.6)
            )
        case .glow: return (
            Color(red: 0.4, green: 0.4, blue: 0.4),
            Color(red: 0.1, green: 0.1, blue: 0.1)
            )
        }
    }
    
}

struct CigaretteElementView:View {
    
    let element: CigaretteElement
    
    var body: some View {
            
            LinearGradient(gradient: Gradient(colors: [element.colors.0, element.colors.1]), startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: Cigarette Glow Dots
struct CigaretteGlowDots:View {
    
    var height: CGFloat
    var width: CGFloat
    let color:Color
    let animated: Bool
    
    @State var appeared:Bool = false
    
    var body: some View {
        
        let dots:Int = Int(height*0.5)
        
        return ZStack {
            
            if dots > 0 {
                
                ForEach((0...dots), id: \.self) { _ in
                    
                    let dotWidth = width * 0.1
                    //let offsetMin = dotWidth / 2
                    let offsetWidth  = (width  - dotWidth) / 2
                    let offsetHeight = (height - dotWidth) / 2
                    
                    CigaretteGlowDot(color: color, animated: animated)
                        .frame(width: dotWidth, height: dotWidth)
                        .blur(radius: 2)
                        .offset(x: CGFloat.random(in: -offsetWidth...offsetWidth), y: CGFloat.random(in: -offsetHeight...offsetHeight))
                        
                    
                }
            }
        }
    }
}

struct CigaretteGlowDot:View {
    
    @State private var appeared:Bool = false
    let color:Color
    let animated:Bool
    let animation:Animation = Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)
    
    var body: some View {
        
        CigaretteGlowTriangle()
            .fill(color.opacity(appeared ? 1 : 0))
            .onAppear {
                appeared = true
            }
            .rotationEffect(Angle(degrees: Double.random(in: (0...360)) + Double(appeared ? 180 : 0)))
            .animation( animated ?
                Animation
                    .easeInOut(duration: 1).repeatForever(autoreverses: true)
                    .delay(Double.random(in: 0...3)) : .none
                , value: appeared)
    }
    
    
    
    struct CigaretteGlowTriangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()

            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))

            return path
        }
    }

}

// MARK: Cigarette Background

struct CigaretteBackgroundBlur: View {
    
    var smokingStarted :Bool
    var smokingProgress:Double
    
    let height: CGFloat
    let backgroundGlowActive:Color
    let backgroundGlowIdle  :Color
    
    var body: some View {
        
        ZStack {
            
            
            if smokingStarted {
                backgroundGlowActive.blur(radius: height * 0.25 + height * 0.1 * smokingProgress)
            } else {
                backgroundGlowIdle.blur(radius: height * 0.15)
                backgroundGlowIdle.blur(radius: height * 0.25)
            }
            
            
            Color.black.blur(radius: 3).offset(x: 2, y: 2)
        }
        
    }
}

