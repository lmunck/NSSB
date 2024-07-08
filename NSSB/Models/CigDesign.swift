//
//  CigDesign.swift
//  NSSB
//
//  Created by Anders Munck on 23/06/2024.
//

import Foundation
import SwiftUI


struct CigDesign:Codable, Equatable, Hashable {
    
    var title:String = "Default"
    
    var widthPercentage:CGFloat = 0.1
    var glowPercentage:Double = 0.1
    var bodyPercentage:Double = 0.75
    var filterPercentage:Double = 0.25
    
    var filter:Color = Color(red: 1.0, green: 0.8, blue: 0.5) //Color(red: 0.6, green: 0.4, blue: 0.1)
    var filterDark:Color { filter.setHSBArelative(brightness: 0.25) }
    var filterDots:Color { filter.setHSBArelative(saturation: 1, brightness: 0.4) }
    var filterArray:[Color] { [filter, filterDark] }
    
    var body:Color =  Color(red: 1.0, green: 1.0, blue: 1.0) //Color(red: 0.6, green: 0.6, blue: 0.6)
    var bodyDark:Color { body.setHSBArelative(brightness: 0.27) }
    var bodyArray:[Color] { [body, bodyDark] }
    
    var ash: Color = Color(red: 0.4, green: 0.4, blue: 0.4)  // Color(red: 0.1, green: 0.1, blue: 0.1)
    var ashDark:Color { ash.setHSBA(brightness: 0.1) }
    var ashArray: [Color] { [ash, ashDark] }
    
    var glow: Color = Color(hue: 0.04, saturation: 1, brightness: 1)
    
    var background: Color = .blue
    
}

extension CigDesign {
    
    // Variations of cigarette color schemes
    static var standard:CigDesign = CigDesign()
    
    static var standardDark:CigDesign = CigDesign(
        title: "Pink ",
        filter: Color(hue: 0.2, saturation: 0.6, brightness: 0.35),
        body: Color(hue: 0.01, saturation: 0.4, brightness: 0.5),
        ash: Color(hue: 0, saturation: 0, brightness: 0.3),
        glow: Color(hue: 0, saturation: 1, brightness: 1))
    
    static var example3:CigDesign = CigDesign(
        title: "Pink ",
        filter: Color(hue: 10, saturation: 0.6, brightness: 0.8),
        body: Color(hue: 220, saturation: 0.2, brightness: 1),
        ash: Color(hue: 0, saturation: 0, brightness: 0.4),
        glow: Color(hue: 0, saturation: 1, brightness: 1))
    
    
    static var exampleArray:[CigDesign] = [standard, standardDark]
}
