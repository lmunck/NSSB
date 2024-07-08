//
//  HueSliderView.swift
//  NSSB
//
//  Created by Anders Munck on 28/06/2024.
//

import SwiftUI

struct HueSliderView: View {
    
    let title:String
    @Binding var color:Color
    
    @State private var colorPreview:Color = .clear
    var previewHSBA:(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        colorPreview.getHSBA()
    }
    
    
    @State private var hueValue:Double = 0
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            Text(title)
            
            HStack {
                
                Slider(value: $hueValue, in: (0...1), step: 0.01) { _ in
                    updateColor()
                }
                    .onChange(of: hueValue) { value in
                        updateColorPreview(value)
                    }
                
                Text(Image(systemName: "circle.fill"))
                    .font(.title)
                    .foregroundStyle(colorPreview)
                
            }
        }
        .onAppear() {
            initSlider()
        }
        
    }
    
    func initSlider() {
        
        // Set preview
        self.colorPreview = self.color
        
        // Set hueValue
        let hsba = self.color.getHSBA()
        self.hueValue = hsba.hue
        
    }
    
    func updateColor() {
        self.color = self.colorPreview
    }
    
    func updateColorPreview(_ hue: Double) {
        self.colorPreview = self.colorPreview.setHSBA(hue: hue)
    }
    
}

#Preview {
    HueSliderView(title: "", color: .constant(.red))
}
