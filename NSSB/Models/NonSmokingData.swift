//
//  NonSmokingData.swift
//  NSSB
//
//  Created by Anders Munck on 04/06/2022.
//

import Foundation
import SwiftUI

struct NonSmokingData:Codable, Equatable {
    
    var cigDates:[Date] = []
    
    var costPer20:Double = 0
    
    // Accent Color
    var accentHue:Int? = 220
    var accentColor:Color {
        var hue:Int = 220
        if let accentHue = accentHue { hue = accentHue}
        return Color(hue: Double(hue)/360, saturation: 0.7, brightness: 1)
    }
    
    // Cigarette Colors
    var cigDesign:CigDesign = CigDesign()
    
    // Savings
    
    func savingsToday() -> Double {
        return Double(self.breaksToday()) * costPer20 / 20
    }
    
    func savingsDailyAvg() -> Double {
        return Double(self.breaksDailyAvg()) * costPer20 / 20
    }
    
    func savingsTotal() -> Double {
        return Double(self.breaksTotal()) * costPer20 / 20
    }
    
    // Breaks
    
    func breaksToday() -> Int {
        
        // Find todays cigarettes
        let todayData = cigDates.filter { NSCalendar.current.isDateInToday($0) }
        
        return todayData.count
    }
    
    func breaksDailyAvg() -> Double {
        
        let totalBreaks = cigDates.count
        
        if let firstDate = cigDates.min(by: { $0 < $1 }) {
            
            if let lastDate  = cigDates.max(by: { $0 < $1 }) {
                
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
        return cigDates.count
    }
    
    
}

// EXTENSION


extension Calendar {
    
    func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
        let fromDate = startOfDay(for: from) // <1>
        
        let toDate = startOfDay(for: to) // <2>
        
        let numberOfDays = dateComponents([.day], from: fromDate, to: toDate) // <3>
        
        return numberOfDays.day!
    }
}

