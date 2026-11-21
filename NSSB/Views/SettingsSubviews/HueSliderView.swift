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
    
    @State private var colorPreview:Color = .white
    
    @State private var hueValue:Double = 0
    
    var body: some View {
        
        GridRow {
            Text(title)
            HStack {
                
                Slider(value: $hueValue, in: (0...1), step: 0.01) { _ in
                    updateColor()
                }
                    .onChange(of: hueValue) { _, value in
                        updateColorPreview(value)
                    }
                
                Text(Image(systemName: "circle.fill"))
                    .foregroundStyle(colorPreview)
                
            }
        }
        .onChange(of: self.color) { _, _ in
            initSlider()
        }
        .onAppear() {
            initSlider()
        }
        
    }
    
    func previewHSBA() -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        return colorPreview.getHSBA()
    }
    
    func initSlider() {
        if self.colorPreview != self.color {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.hueValue = self.color.getHSBA().hue
                self.colorPreview = self.color
            }
        }
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
