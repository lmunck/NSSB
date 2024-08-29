//
//  ExtViewDragToAction.swift
//  NSSB
//
//  Created by Anders Munck on 09/07/2024.
//

import SwiftUI

extension View {
    
    func dragToSelect(menu: Binding<AppMenu>, progress: Binding<Double>, offset: Binding<CGFloat>, snapOffset: CGFloat = 100) -> some View {
        self.modifier(DragToSelect(menu: menu, snapProgress: progress, offset: offset, snapOffset: snapOffset))
    }
        
}

struct DragToSelect: ViewModifier {
    
    @Binding var menu: AppMenu
    @Binding var snapProgress:Double
    @Binding var offset:CGFloat
    
    //@State private var offset = CGSize.zero
    
    let snapOffset:CGFloat
    
    
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset, y: 0)
            .highPriorityGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { gesture in
                        self.offset = gesture.translation.width + initOffset()
                        self.snapProgress = min(abs(gesture.translation.width/(snapOffset/2)), 1)
                    }
                    .onEnded { gesture in
                        checkIfSelect(gesture: gesture)
                    }
            )
            .onChange(of: self.menu) { newValue in
                withAnimation(.easeOut(duration: 0.3)) {
                    self.offset = initOffset()
                }
            }
            
    }
    
    func checkIfSelect(gesture: DragGesture.Value) {
        if abs(gesture.translation.width) > snapOffset/2 {
           
            let dragRight = gesture.translation.width > 0
            
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
        snapProgress = 0
        self.offset = initOffset()
    }
    
    func initOffset() -> CGFloat {
        switch self.menu {
        case .cigarette:    return 0
        case .info:         return -self.snapOffset
        case .settings:     return self.snapOffset
        }
    }
}
