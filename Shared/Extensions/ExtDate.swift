//
//  ExtDate.swift
//  NSSB
//
//  Created by Anders Munck on 27/07/2024.
//

import Foundation

extension Date {
    
    static var breakLength:Double = 10
    
    var elapsedTime: Double {
        return abs(self.timeIntervalSinceNow)
    }
    
    var breakIsActive: Bool {
        if self.elapsedTime < Date.breakLength {
            return true
        } else {
            return false
        }
    }
    
    func breakProgress() -> Double { /// 0 = just started, 1 = ended
        if self.breakIsActive {
            print("TimeIntervalSinceNow: \(self.timeIntervalSinceNow)")
            return self.elapsedTime/Date.breakLength
        } else {
            return 1
        }
    }
    
    func breakSecondsLeft() -> Int {
        
        if self.breakIsActive {
            return abs(Int(Date.breakLength - self.elapsedTime))
        } else {
            return 0
        }
    }
    
    
    
    func breakIsTooClose(to data: Date) -> Bool {
        
        if self.timeIntervalSince(data) < Date.breakLength || data.timeIntervalSince(self) < Date.breakLength {
            return true
        } else {
            return false
        }
    }
}

extension [Date] {
    
    /*
     func getActiveBreakDate() -> Date? {
        return self.first(where: { $0.breakIsActive })
    }
    
    func getBreakProgress() -> Double? { /// 0 = just started, 1 = ended
        
        if let index = self.firstIndex(where: { $0.breakIsActive }) {
            let progress = self[index].breakProgress()
            print("BreakProgress: \(progress)")
            return progress
        } else {
            return nil
        }
    }
    
    func getBreakSecondsLeft() -> Int? {
        
        if let index = self.firstIndex(where: { $0.breakIsActive }) {
            let secondsLeft = self[index].breakSecondsLeft()
            print("SecondsLeft: \(secondsLeft)")
            return secondsLeft
        } else {
            return nil
        }
        
    }
     */
    
    mutating func getNewDates(from newDateArray: [Date]) {
        
        var newDates:[Date] = []
        
        if self != newDateArray {
            
            // Check if new and not too close
            for newBreak in newDateArray {
                if self.contains(newBreak) == false && self.contains(where: { $0.breakIsTooClose(to: newBreak) == false }) {
                    newDates.append(newBreak)
                }
            }
            
            self.append(contentsOf: newDates)
            
        }
    }
    /*
    mutating func startBreak() {
        if self.contains(where:  { $0.breakIsActive }) == false {
            self.append(Date.now)
        }
    }
    
    mutating func stopBreak() {
        if let index = firstIndex(where: { $0.breakIsActive }) {
            self.remove(at: index)
        }
    }
 */
}
