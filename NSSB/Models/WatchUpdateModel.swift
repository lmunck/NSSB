//
//  WatchUpdateModel.swift
//  NSSB
//
//  Created by Anders Munck on 12/06/2022.
//

import Foundation

struct WatchUpdateModel: Codable, Equatable {
    
    var updated:Date
    var breakStarted:Date?
    var totalBreaks:Int
    var todayBreaks:Int
    var design:CigDesign
    
    // traffic control
    var deliveryConfirmed = false
    
}
