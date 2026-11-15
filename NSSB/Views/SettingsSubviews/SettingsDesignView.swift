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
                
                GridRow(alignment: .top) {
                    Text("Name")
                    
                    CigNameWheelsView(title: $design.title)
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
                    Text("Length")
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


struct CigNameWheelsView: View {
    
    @Binding var title: String
    
    private var parts: (adjective: String, noun: String)? { cigNameParts(title) }
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 4) {
            
            // A name typed back when this was a text field. Shown once, struck
            // through, so it is not swapped out behind the user's back - it
            // disappears by itself as soon as they roll.
            if isLegacyCigName(title) {
                Text(title)
                    .strikethrough()
                    .foregroundStyle(.gray)
                Text("Names are rolled now.")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            
            HStack(spacing: 6) {
                
                if let parts = parts {
                    
                    // Two wheels. Tapping one re-rolls that word and leaves
                    // the other alone, which is the whole mechanic - holding a
                    // word is just not tapping it.
                    wheel(parts.adjective) { title = rerollCigAdjective(in: title) }
                    wheel(parts.noun) { title = rerollCigNoun(in: title) }
                    
                    Text(Image(systemName: "xmark.circle.fill"))
                        .foregroundStyle(.gray)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) { title = "" }
                        }
                    
                } else {
                    
                    // No name yet, or a legacy one being replaced. One tap
                    // rolls both words, and teaches that the words are taps.
                    wheel("Roll a name") { title = randomCigaretteName() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func wheel(_ word: String, roll: @escaping () -> Void) -> some View {
        
        Text(word)
            .foregroundStyle(Color.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accent.opacity(0.4), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) { roll() }
            }
    }
}
