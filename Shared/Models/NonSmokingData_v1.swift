//
//  NonSmokingData_v1.swift
//  NSSB
//
//  Created by Anders Munck on 19/08/2024.
//

import Foundation
import SwiftUI

struct NonSmokingData_v1:Codable, Equatable {
    
    var cigDates:[Date] = []
    
    var costPer20:Double = 0
    
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
