//
//  ExtCalendar.swift
//  NSSB
//
//  Created by Anders Munck on 27/07/2024.
//

import SwiftUI

extension Calendar {
    
    func numberOfDaysBetween(_ from: Date, and to: Date) -> Int {
        let fromDate = startOfDay(for: from) // <1>
        
        let toDate = startOfDay(for: to) // <2>
        
        let numberOfDays = dateComponents([.day], from: fromDate, to: toDate) // <3>
        
        return numberOfDays.day!
    }
}
