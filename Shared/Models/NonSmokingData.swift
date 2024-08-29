//
//  NonSmokingData.swift
//  NSSB
//
//  Created by Anders Munck on 04/06/2022.
//

import Foundation
import SwiftUI

struct NonSmokingData:Codable, Equatable {
    
    // Breaks
    var breaks:[Date] = [] /// Variable
    var breakStarted:Date? = nil /// Variable
    
    // Price
    var costPer20:Double = 0 /// Variable
    
    // Accent Color
    var accentHue:Int? = 220 /// Variable
    var accentColor:Color {
        var hue:Int = 220
        if let accentHue = accentHue { hue = accentHue}
        return Color(hue: Double(hue)/360, saturation: 0.7, brightness: 1)
    }
    
    // Cigarette Colors
    var cigDesign:CigDesign = CigDesign() /// Variable
    
    // Calculations
    
    // Savings
    var savingsToday:Double {
        return Double(self.breaksToday) * costPer20 / 20
    }
    var savingsDailyAvg:Double {
        return Double(self.breaksDailyAvg) * costPer20 / 20
    }
    var savingsTotal:Double {
        return Double(self.breaksTotal) * costPer20 / 20
    }
    
    // Breaks
    var breaksToday:Int {
        // Find todays cigarettes
        let todayData = breaks.filter { NSCalendar.current.isDateInToday($0) && $0.breakIsActive == false }
        
        return todayData.count
    }
    
    var breaksDailyAvg:Double {
        
        let totalBreaks = breaksTotal
        
        if let firstDate = breaks.min(by: { $0 < $1 }) {
            
            if let lastDate  = breaks.max(by: { $0 < $1 }) {
                
                let totalDays = Calendar(identifier: .gregorian).numberOfDaysBetween(firstDate, and: lastDate) + 1
                
                if totalDays != 0 {
                    return Double(totalBreaks)/Double(totalDays)
                } else {
                    return -1
                }
                
            } else {
                return Double(breaksToday)
            }
        } else {
            return Double(breaksToday)
        }
        
    }
    
    var breaksTotal: Int {
        return breaks.filter { $0.breakIsActive == false }.count
    }
    
    
}

// Functions
extension NonSmokingData {
    
    func merge(from newData:NonSmokingData, onWatch:Bool = false) -> NonSmokingData? {
        
        if newData != self {
            
            var newSelf = self
            
            // Merge breaks
            for receivedBreak in newData.breaks {
                if newSelf.breaks.contains(receivedBreak) == false {
                    newSelf.breaks.append(receivedBreak)
                }
            }
            
            // Update other data
            newSelf.breakStarted = newData.breakStarted
            
            if onWatch {
                newSelf.costPer20 = newData.costPer20
                newSelf.accentHue = newData.accentHue
            }
            
            newSelf.cigDesign = newData.cigDesign
            
            // Apply changes
            return newSelf
            
        } else {
            return nil
        }
        
    }
    
    
    
    /*func mergeData(from newData: NonSmokingData) -> NonSmokingData {
        
        let oldData = self
        var mergedData = self
        
        if newData.cigDesign != oldData.cigDesign {
            mergedData.cigDesign = newData.cigDesign
        }
        
        let newBreaks = self.getNewBreaks(from: newData)
        if newBreaks.isEmpty == false {
            mergedData.breaks.append(contentsOf: newBreaks)
        }
        
        return mergedData
    }
    
    
    func newBreaks(from data: NonSmokingData) -> [Date] {
        
        var newBreaks:[Date] = []
        
        
        if self.breaks != data.breaks {
            
            // Check if new and not too close to existing break
            for receivedBreak in data.breaks {
                if self.breaks.contains(receivedBreak) == false {
                    newBreaks.append(receivedBreak)
                }
            }
            
            print("newBreaks() - Found \(newBreaks.count)")
            return newBreaks
            
        } else {
            
            print("newBreaks() - No changes")
            return []
        }
    }*/
    
    
}


extension NonSmokingData {
    
    static func ==(lhs: NonSmokingData, rhs: NonSmokingData) -> Bool {
        return lhs.breakStarted == rhs.breakStarted &&
        lhs.breaks == rhs.breaks &&
        lhs.costPer20 == rhs.costPer20 &&
        lhs.accentHue == rhs.accentHue &&
        lhs.cigDesign == rhs.cigDesign
    }
    
}

extension NonSmokingData {
    
    static var example:NonSmokingData = NonSmokingData(breaks: [], costPer20: 10, accentHue: nil, cigDesign: CigDesign.standard)
}
