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
                // .iconOnly keeps the title for VoiceOver, so it already says
                // "Info" - but not that it can be tapped, nor that it is the
                // screen you are looking at.
                .accessibilityAddTraits(menu == .info ? [.isButton, .isSelected] : .isButton)
                .accessibilityHint(menu == .info ? "Goes back to the cigarette" : "Opens info")
            
            Spacer()
            
            Label("Settings", systemImage: menu == .settings ? "gearshape.fill" : "gearshape")
                .labelStyle(.iconOnly)
                .font(.largeTitle)
                .foregroundColor(.accent)
                .contentShape(Rectangle())
                .onTapGesture {
                    if menu == .settings { menu = .cigarette } else { menu = .settings }
                }
                // .iconOnly keeps the title for VoiceOver, so it already says
                // "Settings" - but not that it can be tapped, nor that it is the
                // screen you are looking at.
                .accessibilityAddTraits(menu == .settings ? [.isButton, .isSelected] : .isButton)
                .accessibilityHint(menu == .settings ? "Goes back to the cigarette" : "Opens settings")
            
        }
    }
}

#Preview {
    MenuView(menu: .constant(.cigarette))
}
