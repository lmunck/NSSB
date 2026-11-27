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
    
    /// False for somebody standing there with an unlit cigarette, asking.
    /// The ember is simply absent - no grey stand-in for it, because an
    /// unlit cigarette is exactly a cigarette with nothing at the end.
    var lit: Bool = true
    
    private var width: CGFloat { max(1, height * design.widthPercentage) }
    private var glowHeight: CGFloat { lit ? height * design.glowPercentage : 0 }
    private var filterHeight: CGFloat { height * design.filterPercentage }
    
    /// The body is what burns away.
    private var bodyHeight: CGFloat {
        let full = (design.bodyPercentage + design.glowPercentage) * height - glowHeight
        guard lit else { return full }
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
            if lit {
                RoundedRectangle(cornerRadius: width * 0.2)
                    .fill(design.glow)
                    .frame(width: width, height: glowHeight)
                    .shadow(color: design.glow.opacity(0.9), radius: width * 0.9)
            }
            
            LinearGradient(gradient: Gradient(colors: design.bodyArray),
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: width, height: bodyHeight)
            
            LinearGradient(gradient: Gradient(colors: design.filterArray),
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: width, height: filterHeight)
        }
        .frame(width: width, height: height)
        // Four gradients and no words, which is silence. Whoever is holding
        // this is named by the view that places it, so all this has to say is
        // that somebody is standing out there and whether they are lit.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lit ? "Somebody smoking" : "Somebody waiting, unlit")
    }
}

extension CigDesign {
    
    /// How far down a cigarette of this height the lit end sits.
    ///
    /// What has burned away is empty space above the ember, so the ember
    /// travels down as the cigarette goes - which is why a handoff has to ask
    /// where the tip is rather than assume it is at the top. Falls out of the
    /// same arithmetic the views use: the three parts add up to 1, so the gap
    /// above is exactly the burnt share of the body.
    func tipOffset(height: CGFloat, progress: Double) -> CGFloat {
        height * bodyPercentage * min(max(progress, 0), 1)
    }
}

#Preview {
    HStack(spacing: 30) {
        DistantCigaretteView(design: CigDesign(), progress: 0, height: 90, lit: false)
        DistantCigaretteView(design: CigDesign(), progress: 0.1, height: 90)
        DistantCigaretteView(design: getRandom(), progress: 0.5, height: 70)
        DistantCigaretteView(design: getRandom(), progress: 0.9, height: 110)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
}
