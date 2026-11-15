//
//  DistantCigaretteView.swift
//  NSSB
//

// Somebody else's cigarette, seen from across the courtyard.
//
// Deliberately not CigaretteView. That one owns a timer, notifications, drag
// gestures and a binding to your own data - none of which belongs to a
// stranger. This draws a design at a given burn position and nothing else.

import SwiftUI

struct DistantCigaretteView: View {
    
    let design: CigDesign
    
    /// 0 = just lit, 1 = gone out.
    let progress: Double
    
    let height: CGFloat
    
    private var width: CGFloat { max(1, height * design.widthPercentage) }
    private var glowHeight: CGFloat { height * design.glowPercentage }
    private var filterHeight: CGFloat { height * design.filterPercentage }
    
    /// The body is what burns away.
    private var bodyHeight: CGFloat {
        let full = (design.bodyPercentage + design.glowPercentage) * height - glowHeight
        return max(0, full - full * progress)
    }
    
    /// What has already burned becomes empty space above, so the lit end
    /// travels down the cigarette exactly as it does on your own.
    private var spacerHeight: CGFloat {
        max(0, height - (glowHeight + bodyHeight + filterHeight))
    }
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            Color.clear
                .frame(width: width, height: spacerHeight)
            
            // The lit tip. A plain glow rather than the full ember - at this
            // size the detail is noise, and it would animate twenty times over.
            RoundedRectangle(cornerRadius: width * 0.2)
                .fill(design.glow)
                .frame(width: width, height: glowHeight)
                .shadow(color: design.glow.opacity(0.9), radius: width * 0.9)
            
            LinearGradient(gradient: Gradient(colors: design.bodyArray),
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: width, height: bodyHeight)
            
            LinearGradient(gradient: Gradient(colors: design.filterArray),
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: width, height: filterHeight)
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    HStack(spacing: 30) {
        DistantCigaretteView(design: CigDesign(), progress: 0.1, height: 90)
        DistantCigaretteView(design: getRandom(), progress: 0.5, height: 70)
        DistantCigaretteView(design: getRandom(), progress: 0.9, height: 110)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
}
