//
//  ExtDate.swift
//  NSSB
//
//  Created by Anders Munck on 27/07/2024.
//

import Foundation

extension Date {
    
    static var breakLength:Double = 300
    
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
    
    // Savings
    func savingsToday(costPer20: Double) -> Double {
        return Double(self.breaksToday()) * costPer20 / 20
    }
    func savingsDailyAvg(costPer20: Double) -> Double {
        return Double(self.breaksDailyAvg()) * costPer20 / 20
    }
    func savingsTotal(costPer20: Double) -> Double {
        return Double(self.breaksTotal()) * costPer20 / 20
    }
    
    // Breaks
    func breaksToday() -> Int {
        // Find todays cigarettes
        let todayData = self.filter { NSCalendar.current.isDateInToday($0) }
        
        return todayData.count
    }
    
    func breaksDailyAvg() -> Double {
        
        let totalBreaks = breaksTotal()
        
        if let firstDate = self.min(by: { $0 < $1 }) {
            
            if let lastDate  = self.max(by: { $0 < $1 }) {
                
                let totalDays = Calendar(identifier: .gregorian).numberOfDaysBetween(firstDate, and: lastDate) + 1
                
                if totalDays != 0 {
                    return Double(totalBreaks)/Double(totalDays)
                } else {
                    return -1
                }
                
            } else {
                return Double(breaksToday())
            }
        } else {
            return Double(breaksToday())
        }
        
    }
    
    func breaksTotal() -> Int {
        return self.filter { $0.breakIsActive == false }.count
    }
    
    
    
    
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
