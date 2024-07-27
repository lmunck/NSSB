//
//  ScoreView.swift
//  NSSB
//
//  Created by Anders Munck on 01/06/2022.
//

import SwiftUI


struct InfoView: View {
    
    @Binding var menu:AppMenu
    var data:NonSmokingData
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 10) {
            
            HStack {
                
                Label("Info", systemImage: menu == .settings ? "info.circle.fill" : "info.circle")
                    .labelStyle(.iconOnly)
                    .font(.largeTitle)
                    .foregroundColor(.accent)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if menu == .settings { menu = .cigarette } else { menu = .settings }
                    }
                
                Spacer()
                
            }
            
            if menu == .settings {
                ScrollView(.vertical) {
                    
                    VStack(alignment: .leading, spacing: 30) {
                        
                        VStack(alignment: .leading, spacing: 10) {
                            
                            Text("Cigarette breaks without smoke").font(.title)
                            
                            Text("Breaks are healthy but smoking kills you, so why not have one without the other?")
                            
                            Text("Non-Smoking Smoke Breaks let you relax, go outside, empty a coffee machine, breathe fresh air, and consider life choices without stressing your capillaries.")
                            
                            Text("Non-scientifically proven to have no impact on surgeon generals. May cause health benefits.")
                            
                        }
                        
                        
                        VStack(alignment: .leading, spacing: 10) {
                            
                            Text("v1.2 Update").font(.headline)
                            
                            Text("Thankyouthankyouthankyou for all your downloads and great feedback!")
                            
                            Text("This version let's you create custom smokes and share them with friends. It also gets rid of some pesky bugs.")
                            
                            Text("If you want to support, support a good cause, or learn to code and give me a hand. I can be reached at .")
                            
                            Text("High fives and fist-bumps all you non-smoking rock-stars.")
                            
                            
                            
                            
                        }
                    }
                    
                    .font(.body)
                }
                .transition(.move(edge: .leading))
            }
            
            
            Spacer()
            
        }
        .onTapGesture {
            menu = .cigarette
        }
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView(menu: .constant(.settings), data: NonSmokingData())
    }
}

