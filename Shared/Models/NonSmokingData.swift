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
    var lastUpdate: Date
    
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
    
    func compare(to: NonSmokingData) {
        
        print("DIFFERENCES:")
        if self.breaks != to.breaks {
            print(".breaks")
            var receivedDif:[Date] = []
            for receivedBreak in to.breaks {
                if self.breaks.contains(receivedBreak) == false {
                    receivedDif.append(receivedBreak)
                }
            }
            var localDif:[Date] = []
            for lcocalBreak in self.breaks {
                if to.breaks.contains(lcocalBreak) == false {
                    localDif.append(lcocalBreak)
                }
            }
            print("loc: \(localDif)")
            print("rem: \(receivedDif)")
        }
        if self.breakStarted != to.breakStarted {
            print(".breakStarted")
            print("loc: \(String(describing: self.breakStarted?.description))")
            print("rem: \(String(describing: to.breakStarted?.description))")
        }
        if self.costPer20 != to.costPer20 {
            print(".costPer20")
            print("loc: \(self.costPer20)")
            print("rem: \n \(to.costPer20)")
        }
        if self.accentHue != to.accentHue {
            print(".accentHue")
            print("loc: \(self.accentHue ?? -1)")
            print("rem: \n \(to.accentHue ?? -1)")
        }
        if self.cigDesign != to.cigDesign {
            print(".cigDesign")
        }
        print("")
    }
    
    func older(than receivedObject:NonSmokingData) -> Bool {
        return self.lastUpdate < receivedObject.lastUpdate
    }
    
    func merge(from receivedObject:NonSmokingData) -> NonSmokingData? {
        
        print("MERGE")
        var selfObject = self
        var wasUpdated = false
        
        let isOlder:Bool = selfObject.older(than: receivedObject)
        print("merge() should update: \(isOlder) - \(selfObject.lastUpdate) -> \(receivedObject.lastUpdate)")
        
        if selfObject.breaks != receivedObject.breaks {
            print("merge().breaks: \(selfObject.breaks.count) -> \(receivedObject.breaks.count)")
            for receivedBreak in receivedObject.breaks {
                if selfObject.breaks.contains(receivedBreak) == false {
                    selfObject.breaks.append(receivedBreak)
                    if wasUpdated != true { wasUpdated = true }
                }
            }
            print("merge().breaks: \(selfObject.breaks.count) -> \(receivedObject.breaks.count)")
            selfObject.breaks = selfObject.breaks.sorted()
        }
        
        if selfObject.breakStarted != receivedObject.breakStarted {
            if isOlder {
                print("merge().breakStarted: \(String(describing: selfObject.breakStarted?.description)) -> \(String(describing: receivedObject.breakStarted?.description))")
                if wasUpdated != true { wasUpdated = true }
                selfObject.breakStarted = receivedObject.breakStarted
            }
        }
        
        if selfObject.costPer20 != receivedObject.costPer20 {
            if isOlder {
                print("merge().costPer20: \(selfObject.costPer20) -> \(receivedObject.costPer20)")
                if wasUpdated != true { wasUpdated = true }
                selfObject.costPer20 = receivedObject.costPer20
            }
        }
        
        if selfObject.accentHue != receivedObject.accentHue {
            if isOlder {
                print("merge().accentHue: \(String(describing: selfObject.accentHue)) -> \(String(describing: receivedObject.accentHue))")
                if wasUpdated != true { wasUpdated = true }
                selfObject.accentHue = receivedObject.accentHue
            }
        }
        
        if selfObject.cigDesign != receivedObject.cigDesign {
            if isOlder {
                print("merge().cigDesign: \(selfObject.cigDesign.title) -> \(receivedObject.cigDesign.title)")
                if wasUpdated != true { wasUpdated = true }
                selfObject.cigDesign = receivedObject.cigDesign
            }
        }
        
        if wasUpdated {
            print("merge().lastUpdate: \(selfObject.lastUpdate) -> \(receivedObject.lastUpdate)")
            selfObject.lastUpdate = receivedObject.lastUpdate
        } else {
            print("merge() No updates")
        }
        /*if receivedObject != self {
            
            print("merge() - Received different from self ")
            self.compare(to: receivedObject)
            
            var selfObject = self
            
            // Merge breaks
            for receivedBreak in receivedObject.breaks {
                if selfObject.breaks.contains(receivedBreak) == false {
                    selfObject.breaks.append(receivedBreak)
                    print("merge() - Added break")
                }
            }
            
            // If both have an lastUpdated value and the received is newer, update local
            if let selfUpdated = self.lastUpdated {
                if let receivedUpdated = receivedObject.lastUpdated {
                    if receivedUpdated > selfUpdated {
                        print("merge() - Both had lastUpdated value, but the received is newer, so updating locally")
                        selfObject.cigDesign = receivedObject.cigDesign
                        selfObject.costPer20 = receivedObject.costPer20
                        selfObject.breakStarted = receivedObject.breakStarted
                        selfObject.accentHue = receivedObject.accentHue
                    }
                }
                
                
            // If only the received has a lastUpdated value, update local
            } else if self.lastUpdated == nil && receivedObject.lastUpdated != nil {
                selfObject.cigDesign = receivedObject.cigDesign
                selfObject.costPer20 = receivedObject.costPer20
                selfObject.breakStarted = receivedObject.breakStarted
                selfObject.accentHue = receivedObject.accentHue
                
                
                print("merge() - Only the received had last updated, so updating locallly")
                
            } else {
                
                
                print("merge() - No LastUpdated values or lastUpdated values are equal: self.\(String(describing: self.lastUpdated?.description)) vs received:\(String(describing: receivedObject.lastUpdated?.description))")
            }
            
            // Apply changes
            return selfObject
            
        } else {
            
            print("merge() - No change detected")
            return self
        }
        */
        
        return selfObject
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
    
    static var example:NonSmokingData = NonSmokingData(breaks: [], costPer20: 10, accentHue: nil, cigDesign: CigDesign.standard, lastUpdate: Date.now)
}
