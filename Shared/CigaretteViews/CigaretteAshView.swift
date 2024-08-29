//
//  CigaretteAshView.swift
//  NSSB
//
//  Created by Anders Munck on 25/06/2024.
//

import SwiftUI

struct CigaretteAshView: View {
    
    let design:CigDesign
    let height:CGFloat
    let width:CGFloat
    
    @State private var blurRadius:CGFloat = 8
    
    var body: some View {
        ZStack {
            
            Rectangle()
                .fill(design.glow.opacity(0.8))
                .blur(radius: blurRadius)
                .onAppear {
                    withAnimation(.easeInOut(duration: 3).repeatForever()) {
                        blurRadius = 14
                    }
                }
            
            Rectangle()
                .fill(design.glow.opacity(0.5))
                .blur(radius: 14)
            
            Rectangle()
                .fill(LinearGradient(gradient: Gradient(colors: design.ashArray), startPoint: .leading, endPoint: .trailing))
                .cornerRadius(width/7, corners: [.topLeft, .topRight])
            
            CigaretteGlowDots(height: height, width: width, color: design.glow, animated: true)
            
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    CigaretteAshView(design: CigDesign.standard, height: 50, width: 50)
}
