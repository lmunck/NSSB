//
//  CigaretteView.swift
//  NSSB
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI
import UserNotifications
import Combine

struct CigaretteView: View {
    
    // Menu
    @Binding var menu:AppMenu
    var cigOpacity:CGFloat = 1
    
    /// Somebody in the courtyard gave you a light.
    ///
    /// Set from outside when the two tips touch, and the cigarette lights
    /// itself exactly as a tap would - including the notification at the end
    /// of the break, which is the one thing lighting up sets up that nothing
    /// else does. Nil everywhere else, and always nil on the watch, which has
    /// no courtyard.
    var litByStranger:Date? = nil
    
    @State private var appeared:Bool = false
    
    // Cigarette design
    var height:CGFloat
    
    // Progress
    @Binding var data:NonSmokingData
    var design:CigDesign {
        data.cigDesign
    }
    @State private var breakProgress:Double? = nil
    @State private var secondsLeft:Int = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Actions
    //var breakCompleted:() -> Void
    
    // Cigarette dimensions
    var glowHeight:CGFloat {
        self.breakProgress != nil ? self.height * design.glowPercentage : 0
    }
    var bodyHeight:CGFloat {
        let fullHeight:CGFloat = (design.bodyPercentage + design.glowPercentage) * self.height - self.glowHeight
        if let breakProgress = self.breakProgress {
            var bodyHeight = fullHeight - fullHeight * breakProgress
            if bodyHeight < 0 { bodyHeight = 0 }
            return bodyHeight
        } else {
            return fullHeight
        }
    }
    var filterHeight:CGFloat {
        return self.height * design.filterPercentage
    }
    var spacerHeight:CGFloat {
        let elements:CGFloat = (glowHeight + bodyHeight + filterHeight)
        if elements < self.height {
            let leftoverHeight:CGFloat = self.height - elements
            return leftoverHeight
        } else {
            return 0
        }
    }
    var width:CGFloat {
        return self.height * design.widthPercentage
    }
    
    
    /// What the cigarette would say if you asked it.
    ///
    /// `secondsLeft` is already kept current by the timer that drives the
    /// countdown, so saying this out loud costs nothing that was not already
    /// being worked out.
    private var spokenState: String {
        guard data.breakStarted != nil else { return "Not lit" }
        let minutes = secondsLeft / 60
        let seconds = secondsLeft % 60
        func plural(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
        if minutes > 0 {
            return "Burning, \(plural(minutes, "minute")) \(plural(seconds, "second")) left"
        }
        return "Burning, \(plural(seconds, "second")) left"
    }

    var body: some View {
        
        return ZStack {
            
            Color.clear
            
            VStack(spacing: 0) {
                
                Color.clear
                    .frame(width: width, height: spacerHeight)
                
                // GLOW
                if glowHeight != 0 {
                    
                    CigaretteAshView(design: design, height: glowHeight, width: width)
                        .frame(width: width, height: glowHeight)
                    
                }
                
                // BODY
                LinearGradient(gradient: Gradient(colors: design.bodyArray), startPoint: .leading, endPoint: .trailing)
                .frame(width: width, height: bodyHeight)
                
                // FILTER
                ZStack {
                    
                    LinearGradient(gradient: Gradient(colors: design.filterArray), startPoint: .leading, endPoint: .trailing)
                    
                    CigaretteGlowDots(height: filterHeight, width: width, color: design.filterDots, animated: false)
                    
                }
                .frame(width: width, height: filterHeight)
                
            }
            .frame(width: width, height: self.height)
            .transition(.opacity)
            .onTapGesture {
                toggleSmokebreak()
            }
            // Without this VoiceOver finds a stack of gradients and a tap
            // gesture, which is to say nothing at all: no name, no state, and
            // no reason to believe it can be touched. The whole cigarette
            // becomes one button that says which cigarette it is, how far
            // through the break it has got, and what a tap would do.
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(design.title.isEmpty ? "Cigarette" : design.title)
            .accessibilityValue(spokenState)
            .accessibilityHint(data.breakStarted == nil
                               ? "Starts a five minute non-smoking break"
                               : "Puts it out and cancels the break")
            .background {
                
                let wave:CGFloat = sin((breakProgress ?? 0) * Date.breakLength) * 0.5 + 0.5
                let backWidth = self.height * 0.3
                let backOpacity = 0.5 * wave + (self.cigOpacity * 0.5)
                
                design.background
                    .mask(Ellipse())
                    .frame(width: backWidth, height: self.height * 1.2)
                    .blur(radius: backWidth * 0.4)
                    .opacity(backOpacity)
                    //.edgesIgnoringSafeArea(.all)
            }
            
            // TITLE
            #if os(iOS)
                Text(design.title)
                    .font(.headline)
                    .fixedSize()
                    .foregroundStyle(.white)
                    .frame(width: self.height, alignment: .trailing)
                    .rotationEffect(.degrees(90), anchor: .center)
                    .offset(x: -width / 2 - 10, y: 0)
                    .frame(width: width)
                    .opacity(cigOpacity)
                    // Written up the side of the cigarette, and already the
                    // first thing the cigarette itself says. Twice would be
                    // twice.
                    .accessibilityHidden(true)
            
                ShareCigaretteView(cigarette: design)
                    .foregroundStyle(Color.accent)
                    .frame(height: self.height, alignment: .bottom)
                    .offset(x: width / 2 + 22, y: 0)
                    .opacity(cigOpacity)
                    
            #endif
            
        }
        .onChange(of: data.breakStarted) { _, _ in
            updateSmokebreak()
        }
        .onChange(of: litByStranger) { _, arrived in
            // Only ever lights, never puts out: a gift cannot stub out a
            // cigarette you had already lit yourself.
            //
            // The instant matters as well as the fact. Being lit by a
            // stranger, it is the moment the tips touched, which is now. In a
            // shared break it is the one instant both cigarettes were lit at,
            // which may be a fraction of a second ago - and using it rather
            // than `now` is what makes the two of them go out together.
            if let arrived = arrived, data.breakStarted == nil { lightUp(at: arrived) }
        }
        .onReceive(timer, perform: { _ in
           updateSmokebreak()
        })
        .onAppear() {
            updateSmokebreak(animated: false)
            withAnimation(.easeOut(duration: 0.2)) {
                self.appeared = true
            }
        }
    }
    
    func updateSmokebreak(animated: Bool = true) {
        
        if let startDate = self.data.breakStarted {
            
            if startDate.breakIsActive {
                
                // Break is still active, so update progress
                self.secondsLeft = startDate.breakSecondsLeft()
                withAnimation(animated ? .linear(duration: 1) : .none) {
                    if secondsLeft == 0 {
                        breakProgress = 1
                    } else {
                        self.breakProgress = startDate.breakProgress()
                    }
                }
            } else {
                
                // Break is no longer active, so save break
                if let startDate = self.data.breakStarted {
                    var temp = self.data
                    temp.breaks.append(startDate)
                    temp.breakStarted = nil
                    self.data = temp
                }
                
                // Reset Vars
                if self.breakProgress != nil {
                    self.breakProgress = nil
                }
                if self.secondsLeft != 0 {
                    self.secondsLeft = 0
                }
            }
                
        } else {
            
            // Break is nill, so reset any local vars that are not reset
            if self.breakProgress != nil {
                self.breakProgress = nil
            }
            if self.secondsLeft != 0 {
                self.secondsLeft = 0
            }
            
        }
    }
    
    // Smoke update update
    func toggleSmokebreak() {
        if menu != .cigarette {
            self.menu = .cigarette
        } else {
            if self.data.breakStarted != nil {
                self.breakProgress = nil
                self.data.breakStarted = nil
                removeNotifications()
            } else {
                lightUp()
            }
            //sendUpdate()
            
        }
    }
    
    /// Lights the cigarette. One place, whether it was a tap or a stranger.
    func lightUp(at instant: Date = .now) {
        
        // A cigarette needs a name before it can stand in the courtyard, and
        // plenty of people never open Customize. Roll one here rather than
        // publishing a nameless cigarette.
        //
        // Set in the same mutation as breakStarted, so the name is already in
        // place by the time anything observes the break starting - otherwise
        // presence publishes the empty title.
        var temp = self.data
        if temp.cigDesign.title.isEmpty {
            temp.cigDesign.title = randomCigaretteName()
        }
        temp.breakStarted = instant
        self.data = temp
        
        self.breakProgress = 0
        setNotification()
    }
    
    /// The tap on the shoulder at the end of the break, and the only place the
    /// app asks whether it may give you one.
    ///
    /// It used to schedule into a void. The single `requestAuthorization` in
    /// the project was in Settings -> Reminders, behind a guard that only
    /// fires once a reminder frequency has been chosen, so anyone who
    /// installed the app, took a break and never went looking for the reminder
    /// screen got nothing at the end of it - silently, because adding a
    /// request without permission fails without telling anybody. The
    /// notification at the end of a break is the feature; the random daily
    /// reminders are the optional extra, and permission was only ever asked
    /// for the extra.
    ///
    /// Lighting up is also the one moment where the question explains itself:
    /// the answer to it arrives in five minutes.
    func setNotification() {
        
        func addNotification(at trigger: UNNotificationTrigger) {
            
            let content = UNMutableNotificationContent()
            content.title = "Non-smoking break completed!"
            content.subtitle = "Time to get back to the grind."
            content.sound = UNNotificationSound.default

            let request = UNNotificationRequest(identifier: "smokeBreakOngoing", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
            
        }
        
        guard let secondsLeft:Int = self.data.breakStarted?.breakSecondsLeft() else { return }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(secondsLeft), repeats: false)
        let centre = UNUserNotificationCenter.current()
        
        centre.getNotificationSettings { settings in
            
            switch settings.authorizationStatus {
                
            case .notDetermined:
                // The same options ReminderView asks for, so whichever screen
                // gets there first, the other finds what it needs. Asked once:
                // after this the status is authorized or denied, never
                // notDetermined again, so a second break does not re-prompt.
                centre.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error = error { Log.notifications.error("setNotification() - \(error.localizedDescription)") }
                    guard granted else { return }
                    addNotification(at: trigger)
                }
                
            case .authorized, .provisional, .ephemeral:
                addNotification(at: trigger)
                
            case .denied:
                // Nothing to schedule and nothing to ask: iOS only shows the
                // prompt once, and after a no it is the user's Settings app.
                Log.notifications.debug("setNotification() - notifications are off, nothing scheduled")
                
            @unknown default:
                Log.notifications.debug("setNotification() - unknown authorization status")
            }
        }
    }
    
    func removeNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["smokeBreakOngoing"])
    }
    
}

struct CigaretteView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        #if os(iOS)
        
        CigaretteView(menu: .constant(.cigarette), height: 400, data: .constant(NonSmokingData.example))
        
        #else
        
        CigaretteView(menu: .constant(.cigarette), height: 164, data: .constant(NonSmokingData.example))
        
        #endif
            
    }
}



