//
//  MenuView.swift
//  NSSB
//
//  Created by Anders Munck on 25/08/2024.
//

import SwiftUI

struct MenuView: View {
    
    @Binding var menu:AppMenu
    
    var body: some View {
        
        HStack {
            
            Label("Info", systemImage: menu == .info ? "info.circle.fill" : "info.circle")
                .labelStyle(.iconOnly)
                .font(.largeTitle)
                .foregroundColor(.accent)
                .contentShape(Rectangle())
                .onTapGesture {
                    if menu == .info { menu = .cigarette } else { menu = .info }
                }
            
            Spacer()
            
            Label("Settings", systemImage: menu == .settings ? "gearshape.fill" : "gearshape")
                .labelStyle(.iconOnly)
                .font(.largeTitle)
                .foregroundColor(.accent)
                .contentShape(Rectangle())
                .onTapGesture {
                    if menu == .settings { menu = .cigarette } else { menu = .settings }
                }
            
        }
    }
}

#Preview {
    MenuView(menu: .constant(.cigarette))
}
