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
                
                Label("Info", systemImage: menu == .stats ? "info.circle.fill" : "info.circle")
                    .labelStyle(.iconOnly)
                    .font(.largeTitle)
                    .foregroundColor(.accent)
                    .padding()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if menu == .stats { menu = .cigarette } else { menu = .stats }
                    }
                
                Spacer()
                
            }
            
            if menu == .stats {
                
                VStack(alignment: .leading, spacing: 10) {
                    
                    Text("Cigarette breaks without smoke").font(.title)
                    
                    Text("Breaks are healthy but smoking kills you, so why not have one without the other?")
                    
                    Text("Non-Smoking Smoke Breaks let you relax, go outside, empty a coffee machine, breathe fresh air, and consider life choices without stressing your capillaries.")
                    
                    Text("Non-scientifically proven to have no impact on surgeon generals. May cause health benefits.")
                    
                    
                }
                .font(.body)
                .padding()
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
        InfoView(menu: .constant(.stats), data: NonSmokingData())
    }
}

