//
//  ReminderRepository.swift
//  NSSB
//
//  Created by Anders Munck on 06/06/2022.
//

// Logic for managing reminders

import Foundation
import NotificationCenter

class ReminderRepository: ObservableObject {
    
    // Stable identifiers so a rescheduled set replaces the previous one instead
    // of stacking on top of it. Bounded by the largest option the UI offers.
    private static let reminderPrefix = "dailyReminder-"
    private static let maxReminders = 20
    
    func setReminders(_ perDay: Int) {
        
        print("per day \(perDay)")
        
        // Always clear the previously scheduled reminders first. Only our own
        // reminder identifiers are removed, so an ongoing break notification
        // is left alone.
        let staleIDs:[String] = (0..<ReminderRepository.maxReminders).map { "\(ReminderRepository.reminderPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: staleIDs)
        
        guard perDay != 0 else {
            print("Removed reminders")
            return
        }
        
        for (index, trigger) in getDailyTriggers(perDay).enumerated() {
            addStartNotification(at: trigger, index: index)
        }
    }
    
    
    
    private func getDailyTriggers(_ remindersPerDay: Int) -> [UNNotificationTrigger] {
        
        // Double check for invalid value
        guard remindersPerDay > 0 else {
            return []
        }
        
        // Time-interval is 8am to 8pm = 12 hours * 60 mins * 60 secs
        let secondsPerDay:Int = 12 * 60 * 60 ; print("\(secondsPerDay)")
        let secondsInterval = Int(secondsPerDay/remindersPerDay)
        
        
        print("secondsDelta: \(secondsInterval)")
        print("-----")
        
        var triggers:[UNNotificationTrigger] = []
        
        // Get delta from 8am in seconds
        for n in (0...remindersPerDay - 1) {
            
            print("Reminder: \(n)")
            
            // Calculate delta from start time (8 am)
            var secondsDelta = n * secondsInterval
            
            // Make random
            
            // Max value for randomness, if larger it will overlap next reminder
            let randomMax:Int = secondsInterval / 2
            
            // Define random value within limits
            let randomDelta:Int = Int.random(in: -randomMax...randomMax)
            
            // Calculate
            secondsDelta = secondsDelta + randomMax + randomDelta
            
            // Get date values
            let hours:Int = 8 + (secondsDelta % 86400) / 3600 ; print("Hour \(hours)")
            let minutes:Int = (secondsDelta % 3600) / 60; print("Mins \(minutes)")
            let seconds:Int = (secondsDelta % 3600) % 60 ; print("Secs \(seconds)")
            
            var components = DateComponents()
            components.hour = hours
            components.minute = minutes
            components.second = seconds
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            triggers.append(trigger)
            
        }
        
        return triggers
    }
    
    private func addStartNotification(at trigger: UNNotificationTrigger, index: Int) {
        
        let content = UNMutableNotificationContent()
        content.title = "Take a Non-Smoking Smoke Break"
        content.subtitle = "It's healthy and you deserve it."
        content.sound = UNNotificationSound.default

        // Stable identifier, so rescheduling replaces this reminder
        let request = UNNotificationRequest(identifier: "\(ReminderRepository.reminderPrefix)\(index)", content: content, trigger: trigger)

        // add our notification request
        UNUserNotificationCenter.current().add(request)
        
    }
    
    
    
    func checkIfNight() -> Int {
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date.now)
        let hour:Int = components.hour ?? 0
        //let minute:Int = components.minute ?? 0
        
        
        
        return hour
    }
    
}
