//
//  ExtViewDragToAction.swift
//  NSSB
//
//  Created by Anders Munck on 09/07/2024.
//

import SwiftUI

extension View {
    
    func dragToSelect(menu: Binding<AppMenu>) -> some View {
        self.modifier(DragToSelect(menu: menu))
    }
        
}

struct DragToSelect: ViewModifier {
    
    @Binding var menu: AppMenu
    
    @State private var offset = CGSize.zero
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        //if abs(gesture.translation.width) < 100 {
                            offset.width = gesture.translation.width
                        //checkIfSelect(gesture: gesture)
                        //}
                    }
                    .onEnded { gesture in
                        
                        checkIfSelect(gesture: gesture)
                        
                    }
            )
            
    }
    
    func checkIfSelect(gesture: DragGesture.Value) {
        if abs(gesture.translation.width) > 100 {
           
            let dragRight = gesture.translation.width > 0
            
            print("DragRight: \(gesture.translation.width)")
            
            if dragRight {
                if menu == .info {
                    menu = .cigarette
                } else if menu == .cigarette {
                    menu = .settings
                }
                resetOffset()
            } else {
                if menu == .settings {
                    menu = .cigarette
                } else if menu == .cigarette {
                    menu = .info
                }
                resetOffset()
            }
            
        } else {
            resetOffset()
        }
    }
    
    func resetOffset() {
        //withAnimation(.easeInOut(duration: 0.4)) {
            offset = .zero
        //}
    }
}
