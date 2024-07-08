//
//  CigaretteGlowDots.swift
//  NSSB
//
//  Created by Anders Munck on 24/06/2024.
//

import SwiftUI

// MARK: Cigarette Glow Dots
struct CigaretteGlowDots:View {
    
    var height: CGFloat
    var width: CGFloat
    let color:Color
    let animated: Bool
    
    @State var appeared:Bool = false
    
    var body: some View {
        
        let dots:Int = Int(height*0.5)
        
        return ZStack {
            
            if dots > 0 {
                
                ForEach((0...dots), id: \.self) { _ in
                    
                    let dotWidth = width * 0.1
                    //let offsetMin = dotWidth / 2
                    let offsetWidth  = (width  - dotWidth) / 2
                    let offsetHeight = (height - dotWidth) / 2
                    
                    CigaretteGlowDot(color: color, animated: animated)
                        .frame(width: dotWidth, height: dotWidth)
                        .blur(radius: 2)
                        .offset(x: CGFloat.random(in: -offsetWidth...offsetWidth), y: CGFloat.random(in: -offsetHeight...offsetHeight))
                        
                    
                }
            }
        }
    }
}


#Preview {
    CigaretteGlowDots(height: 50, width: 50, color: .blue, animated: true)
}


struct CigaretteGlowDot:View {
    
    @State private var appeared:Bool = false
    let color:Color
    let animated:Bool
    let animation:Animation = Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)
    
    var body: some View {
        
        CigaretteGlowTriangle()
            .fill(color.opacity(appeared ? 1 : 0))
            .onAppear {
                appeared = true
            }
            .rotationEffect(Angle(degrees: Double.random(in: (0...360)) + Double(appeared ? 180 : 0)))
            .animation( animated ?
                Animation
                    .easeInOut(duration: 1).repeatForever(autoreverses: true)
                    .delay(Double.random(in: 0...3)) : .none
                , value: appeared)
    }
    
    
    
    struct CigaretteGlowTriangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()

            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))

            return path
        }
    }

}
