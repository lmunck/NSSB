//
//  ExtColor.swift
//  NSSB
//
//  Created by Anders Munck on 26/06/2024.
//

import SwiftUI

extension Color {
    
    func getHSBA() -> (hue:CGFloat, saturation:CGFloat, brightness: CGFloat, alpha: CGFloat) {
        let uiColor = UIColor(self)
        
        var hue: CGFloat  = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return (hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
    
    func getRGBA() -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        
        let uiColor = UIColor(self)
        
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func setHSBA(hue: CGFloat? = nil, saturation: CGFloat? = nil, brightness: CGFloat? = nil, alpha: CGFloat? = nil) -> Color {
        let hsba = self.getHSBA()
        return Color(hue: hue ?? hsba.hue, saturation: saturation ?? hsba.saturation, brightness: brightness ?? hsba.brightness, opacity: alpha ?? hsba.alpha)
    }
    
    func setHSBArelative(hue: CGFloat? = nil, saturation: CGFloat? = nil, brightness: CGFloat? = nil, alpha: CGFloat? = nil) -> Color {
        let hsba = self.getHSBA()
        return Color(hue: (hue ?? 1) * hsba.hue, saturation: (saturation ?? 1) * hsba.saturation, brightness: (brightness ?? 1) * hsba.brightness, opacity: (alpha ?? 1) * hsba.alpha)
    }
    
}
