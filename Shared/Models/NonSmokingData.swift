//
//  NonSmokingData.swift
//  NSSB
//
//  Created by Anders Munck on 04/06/2022.
//

import Foundation
import SwiftUI

struct NonSmokingData:Codable {
    
    // Breaks
    var breaks:[Date] = [] /// Variable
    var breakStarted:Date? = nil /// Variable
    
    // Price
    var costPer20:Double = 0 /// Variable
    
    // Accent Color
    var accentHue:Int? = 220 /// Variable
    
    
    // Cigarette Colors
    var cigDesign:CigDesign = CigDesign() /// Variable
    
    // Calculations
    var lastUpdate: Date
    
}

extension NonSmokingData: Equatable {
    static func ==(lhs: NonSmokingData, rhs: NonSmokingData) -> Bool {
        
        let lastUpdatesAreEqual = Calendar.current.isDate(lhs.lastUpdate, equalTo: rhs.lastUpdate, toGranularity: .second)
        
        return lhs.breaks == rhs.breaks &&
        lhs.breakStarted == rhs.breakStarted &&
        lhs.costPer20 == rhs.costPer20 &&
        lhs.accentHue == rhs.accentHue &&
        lhs.cigDesign == rhs.cigDesign &&
        lastUpdatesAreEqual
    }
}

// Calculated values
extension NonSmokingData {
    
    func accentColor() -> Color {
        var hue:Int = 220
        if let accentHue = accentHue { hue = accentHue}
        return Color(hue: Double(hue)/360, saturation: 0.7, brightness: 1)
    }
    
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
        let todayData = breaks.filter { NSCalendar.current.isDateInToday($0) && $0.breakIsActive == false }
        
        return todayData.count
    }
    
    func breaksDailyAvg() -> Double {
        
        let totalBreaks = breaksTotal()
        
        if let firstDate = breaks.min(by: { $0 < $1 }) {
            
            if let lastDate  = breaks.max(by: { $0 < $1 }) {
                
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
        return breaks.filter { $0.breakIsActive == false }.count
    }
    
}

// Functions
extension NonSmokingData {
    
    func compare(to other: NonSmokingData) {
        
        let local = self
        
        Log.sync.debug("COMPARE:")
        if local.breaks != other.breaks {
            Log.sync.debug(".breaks")
            var receivedDif:[Date] = []
            for receivedBreak in other.breaks {
                if local.breaks.contains(receivedBreak) == false {
                    receivedDif.append(receivedBreak)
                }
            }
            var localDif:[Date] = []
            for lcocalBreak in local.breaks {
                if other.breaks.contains(lcocalBreak) == false {
                    localDif.append(lcocalBreak)
                }
            }
            Log.sync.debug("loc: \(localDif) .count(\(self.breaks.count))")
            Log.sync.debug("rem: \(receivedDif) .count(\(other.breaks.count))")
        }
        if self.breakStarted != other.breakStarted {
            Log.sync.debug(".breakStarted")
            Log.sync.debug("loc: \(String(describing: local.breakStarted?.description))")
            Log.sync.debug("rem: \(String(describing: other.breakStarted?.description))")
        }
        if local.costPer20 != other.costPer20 {
            Log.sync.debug(".costPer20")
            Log.sync.debug("loc: \(local.costPer20)")
            Log.sync.debug("rem: \n \(other.costPer20)")
        }
        if local.accentHue != other.accentHue {
            Log.sync.debug(".accentHue")
            Log.sync.debug("loc: \(local.accentHue ?? -1)")
            Log.sync.debug("rem: \n \(other.accentHue ?? -1)")
        }
        if self.cigDesign != other.cigDesign {
            local.cigDesign.compare(to: other.cigDesign)
        }
        
    }
    
    
    /// Everything except when it was last touched.
    ///
    /// `==` includes `lastUpdate`, which is the right answer for "is this the
    /// same message" and the wrong one for "did anything actually change".
    func differs(from other: NonSmokingData) -> Bool {
        breaks != other.breaks
            || breakStarted != other.breakStarted
            || costPer20 != other.costPer20
            || accentHue != other.accentHue
            || cigDesign != other.cigDesign
    }
    
    /// Marks this as changed now, unless it already carries somebody else's
    /// stamp or nothing really changed.
    ///
    /// `lastUpdate` has to mean *when this last changed* for `older(than:)`
    /// to be able to order two copies at all. It used to be set at send
    /// time, by both devices, which made every message the newest thing
    /// either of them had ever seen - so whichever device spoke last won the
    /// merge outright. Raising your wrist is a device speaking: the watch
    /// woke up, sent the copy it had been sitting on, and the phone adopted
    /// it, cigarette and all. A watch that has never heard about a running
    /// break sends `breakStarted` nil, and that put it out.
    ///
    /// An arriving copy keeps the stamp it came with, because that is the
    /// moment the change was actually made, on the device that made it.
    mutating func touch(ifChangedFrom old: NonSmokingData) {
        guard differs(from: old), lastUpdate == old.lastUpdate else { return }
        lastUpdate = .now
    }
    
    func older(than receivedObject:NonSmokingData) -> Bool {
        let isSame:Bool = Calendar.current.isDate(self.lastUpdate, equalTo: receivedObject.lastUpdate, toGranularity: .second)
        
        if isSame { return false } else {
            return self.lastUpdate < receivedObject.lastUpdate
        }
    }
    
    func merge(from receivedObject:NonSmokingData) -> NonSmokingData? {
        
        if self != receivedObject {
            
            Log.sync.debug("MERGE")
            var selfObject = self
            var wasUpdated = false
            
            let isOlder:Bool = selfObject.older(than: receivedObject)
            Log.sync.debug("merge() should check for updates: \(isOlder) - \(selfObject.lastUpdate) -> \(receivedObject.lastUpdate)")
            
            if selfObject.breaks != receivedObject.breaks {
                Log.sync.debug("merge().breaks: \(selfObject.breaks.count) -> \(receivedObject.breaks.count)")
                for receivedBreak in receivedObject.breaks {
                    Log.sync.debug("merge().receivedBreak:\(receivedBreak) - contains?\(selfObject.breaks.contains(receivedBreak)) - selfObject.breaks:\(selfObject.breaks)")
                    if selfObject.breaks.contains(receivedBreak) == false {
                        Log.sync.debug("merge().breaks: Added \(receivedBreak)")
                        selfObject.breaks.append(receivedBreak)
                        if wasUpdated != true { wasUpdated = true }
                    }
                }
                selfObject.breaks = selfObject.breaks.uniqued()
                selfObject.breaks = selfObject.breaks.sorted()
            }
            
            if selfObject.breakStarted != receivedObject.breakStarted {
                if isOlder {
                    Log.sync.debug("merge().breakStarted: \(String(describing: selfObject.breakStarted?.description)) -> \(String(describing: receivedObject.breakStarted?.description))")
                    if wasUpdated != true { wasUpdated = true }
                    selfObject.breakStarted = receivedObject.breakStarted
                }
            }
            
            if selfObject.costPer20 != receivedObject.costPer20 {
                if isOlder {
                    Log.sync.debug("merge().costPer20: \(selfObject.costPer20) -> \(receivedObject.costPer20)")
                    if wasUpdated != true { wasUpdated = true }
                    selfObject.costPer20 = receivedObject.costPer20
                }
            }
            
            if selfObject.accentHue != receivedObject.accentHue {
                if isOlder {
                    Log.sync.debug("merge().accentHue: \(String(describing: selfObject.accentHue)) -> \(String(describing: receivedObject.accentHue))")
                    if wasUpdated != true { wasUpdated = true }
                    selfObject.accentHue = receivedObject.accentHue
                }
            }
            
            if selfObject.cigDesign != receivedObject.cigDesign {
                if isOlder {
                    Log.sync.debug("merge().cigDesign: \(selfObject.cigDesign.title) -> \(receivedObject.cigDesign.title)")
                    if wasUpdated != true { wasUpdated = true }
                    selfObject.cigDesign = receivedObject.cigDesign
                }
            }
            
            if wasUpdated {
                selfObject.lastUpdate = receivedObject.lastUpdate
                
                return selfObject
            } else {
                
                Log.sync.debug("merge() No updates")
                return nil
            }
            
        } else {
            
            Log.sync.debug("merge() No updates")
            return nil
        }
        
    }
    
    
}


extension NonSmokingData {
    
    static var example:NonSmokingData = NonSmokingData(breaks: [], costPer20: 10, accentHue: nil, cigDesign: CigDesign.standard, lastUpdate: Date.now)
}
