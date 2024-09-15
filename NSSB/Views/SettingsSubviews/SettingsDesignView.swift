//
//  SettingsColorView.swift
//  NSSB
//
//  Created by Anders Munck on 09/06/2024.
//

import SwiftUI

struct SettingsDesignView: View {
    
    @Binding var design:CigDesign
    //@State private var design = CigDesign.example3
    
    
    let returnAction:() -> Void
    
    let standard = CigDesign.standard
    let dark = CigDesign.standardDark
    
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            /*CigaretteView(menu: .constant(.cigarette), completedBreak: {}, sendUpdate: {}, height: 200, design: design, breakStarted: .constant(Date.now))*/
            
            Label("Customize", systemImage: "paintbrush")
                    .labelStyle(LabelStyleReversed())
                    .font(.title)
                    .padding(.bottom, 5)
            
            
            Grid(alignment: .leading) {
                
                GridRow {
                    Text("Name")
                    
                    TitleTextFieldView(title: $design.title)
                        .background( Rectangle().fill(.black).cornerRadius(3))
                        
                }
                
                HueSliderView(title: "Back", color: $design.background)
                
                
                HueSliderView(title: "Glow", color: $design.glow)
                //Text("\(design.glow.getHSBA())").font(.footnote)
                
                
                HueSelectorView(title: "Body", color: $design.body, colorDefault: standard.body, colorAlternative: dark.body)
                
                
                HueSelectorView(title: "Filter", color: $design.filter, colorDefault: standard.filter, colorAlternative: dark.filter)
                
                GridRow {
                    Text("Width")
                    Slider(value: $design.widthPercentage, in: CigDesign.widthRange)
                }
                
                GridRow {
                    Text("Filter")
                    Slider(value: $design.filterPercentage, in: CigDesign.filterRange)
                }
            }
            
            // PRESET MENU
            HStack {
                Label("Randomize", systemImage: "wand.and.stars")
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.design = getRandom()
                        }
                    }
                Spacer()
                Label("Default", systemImage: "trash")
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.design = standard
                        }
                    }
            }
            .padding(.top, 10)
            .foregroundStyle(Color.accent)
            
        }
        
    }
}

#Preview {
    VStack {
        SettingsDesignView(design: .constant(CigDesign.standard), returnAction: {})
    }.background(.black)
        .foregroundStyle(.gray)
}


import Combine

struct TitleTextFieldView:View {
    
    @Binding var title: String
    
    @State private var tempTitle:String = ""
    
    let textLimit = 50
    
    var body: some View {
        HStack(spacing: 0) {
            
            TextField("Custom name", text: $tempTitle, onCommit: { self.title = String(tempTitle.prefix(70)) })
                .onReceive(Just(tempTitle)) { _ in limitText(textLimit) }
                .padding(3)
                .foregroundStyle(Color.accent)
            
            Text(Image(systemName: "xmark.circle.fill"))
                .onTapGesture {
                    self.tempTitle = ""
                    self.title = ""
                }
                .opacity(self.tempTitle.count != 0 ? 1 : 0)
        }
        .onAppear { tempTitle = title }
        
        // Check if title is changed from outside this view
        .onChange(of: self.title) { new in
            if new != self.tempTitle {
                self.tempTitle = new
            }
        }
    }
    
    //Function to keep text length in limits
        func limitText(_ upper: Int) {
            if tempTitle.count > upper {
                tempTitle = String(tempTitle.prefix(upper))
            }
        }
    
}
