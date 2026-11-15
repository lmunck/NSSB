//
//  ColorCodable.swift
//  NSSB
//
//  Created by Anders Munck on 09/06/2024.
//

// A Codable stand-in for SwiftUI's Color.
//
// This file used to declare `extension Color: Codable`, a retroactive
// conformance to a type the app does not own. The compiler warns that it
// "will not behave correctly if the owner adds conformance", and that stopped
// being theoretical once CigDesign became a wire format: it is written to the
// saved file, sent to the watch, packed into share URLs and stored in
// Firestore. If Apple ever adds Codable to Color, the encoding could change
// underneath all four at once.
//
// CodableColor is an ordinary struct this app owns. It encodes to exactly the
// same JSON the old extension produced - {"red":_, "green":_, "blue":_} - so
// every file, URL and document written before this change still decodes.

import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#elseif os(macOS)
import AppKit
#endif

extension Color {
    
    #if os(macOS)
    typealias SystemColor = NSColor
    #else
    typealias SystemColor = UIColor
    #endif
    
    /// Nil for a colour that cannot be expressed as RGB.
    var colorComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        #if os(macOS)
        SystemColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        guard SystemColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }
        #endif
        
        return (r, g, b, a)
    }
}

/// Three channels, stored as the app's own type rather than SwiftUI's.
struct CodableColor: Codable, Equatable, Hashable {
    
    var red: Double
    var green: Double
    var blue: Double
    
    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
    
    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
    
    /// Falls back to mid-grey for a colour with no RGB representation. The old
    /// extension encoded nothing at all in that case, which wrote an empty
    /// object that then failed to decode - a silently corrupted design.
    init(_ color: Color) {
        
        guard let parts = color.colorComponents else {
            self.init(red: 0.5, green: 0.5, blue: 0.5)
            return
        }
        
        self.init(red: Double(parts.red), green: Double(parts.green), blue: Double(parts.blue))
    }
}

extension Color {
    var codable: CodableColor { CodableColor(self) }
}
