//
//  SettingsColorView.swift
//  NSSB
//
//  Created by Anders Munck on 09/06/2024.
//

import SwiftUI

struct SettingsColorView: View {
    
    @Binding var design:CigDesign
    @State private var design2 = CigDesign()
    
    let returnAction:() -> Void
    
    let standard = CigDesign.standard
    let dark = CigDesign.standardDark
    
    var body: some View {
        
        
        VStack(spacing: 0) {
            
            HStack {
                
                Text("Colors")
                Spacer()
                Text("\(design2.body.getHSBA().hue)")
            }
            .font(.title)
            
            HueSliderView(title: "Background", color: $design2.background)
            
            HueSliderView(title: "Glow", color: $design2.glow)
            
            HueSelectorView(title: "Body", color: $design2.body, colorDefault: standard.body, colorAlternative: dark.body)
            
            HueSelectorView(title: "Filter", color: $design2.filter, colorDefault: standard.filter, colorAlternative: dark.filter)
            
            
            HStack {
                Spacer()
                Text(Image(systemName: "trash.fill"))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.design2 = CigDesign()
                        }
                    }
            }
        }
        
    }
}

#Preview {
    VStack {
        SettingsColorView(design: .constant(CigDesign()), returnAction: {})
    }.background(.black)
        .foregroundStyle(.gray)
}


