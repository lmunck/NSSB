//
//  HueSelectorView.swift
//  NSSB
//
//  Created by Anders Munck on 28/06/2024.
//

import SwiftUI

struct HueSelectorView: View {
    
    let title:String
    @Binding var color:Color
    
    var colorDefault:Color
    var defHSBA:(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        colorDefault.getHSBA()
    }
    
    var colorAlternative:Color
    var altHSBA:(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        colorAlternative.getHSBA()
    }
    
    @State private var colorPreview:Color = .clear
    var previewHSBA:(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        colorPreview.getHSBA()
    }
    
    var defaultSelected:Bool {
        previewHSBA.brightness == defHSBA.brightness
    }
    
    
    @State private var hueValue:Double = 0
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            Text(title)
            
            HStack {
                
                Slider(value: $hueValue, in: (0...1), step: 0.01) { _ in
                    updateColor()
                }
                
                Text(Image(systemName: "circle.fill"))
                    .font(.title)
                    .foregroundStyle(colorPreview)
                
            }
        } 
        .onChange(of: hueValue) { value in
            updateColorPreview(value)
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
        
        var previewHSBA = colorPreview.getHSBA()
        
        if self.hueValue == 0 {
            previewHSBA.saturation = 0
            previewHSBA.brightness = defHSBA.brightness
        } else if self.hueValue == 1 {
            previewHSBA.saturation = 0
            previewHSBA.brightness = altHSBA.brightness
        } else {
            let newSaturation:CGFloat = max(defaultSelected ? defHSBA.saturation : altHSBA.brightness, 0.2)
            previewHSBA.saturation = newSaturation
            previewHSBA.brightness = defaultSelected ? defHSBA.brightness : altHSBA.brightness
        }
            
        previewHSBA.hue = hueValue
            
        self.colorPreview = self.colorPreview.setHSBA(hue: previewHSBA.hue, saturation: previewHSBA.saturation, brightness: previewHSBA.brightness)
        
    }
    
}

#Preview {
    HueSelectorView(title: "Test", color: .constant(CigDesign.standard.body), colorDefault: CigDesign.standard.body, colorAlternative: CigDesign.standardDark.body)
}
