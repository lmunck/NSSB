//
//  Focus.swift
//  NSSB
//
//  Created by Anders Munck on 10/06/2022.
//

import SwiftUI


extension View {
    
    func focus(active: Binding<Bool>, duration: Double = 0.5, type: FocusType = .expand) -> some View {
        self.modifier(FocusAnimation(active: active, duration: duration, type: type))
    }
}

enum FocusType: Equatable, CaseIterable {
    case expand, wiggle, pop
    
    var title:String {
        switch self {
        case .expand: return "Expand"
        case .wiggle: return "Wiggle"
        case .pop: return "Pop"
        }
    }
}

// MARK: FocusAnimation

struct FocusAnimation:AnimatableModifier {
    
    @Binding var active:Bool
    
    @State private var animation:Bool = false
    
    let duration: Double
    let type:FocusType
    
    func body(content: Content) -> some View {
        
        ZStack {
            
            switch type {
            
            case .expand:
                content
                    .scaleEffect(animation ? 0.9 : (active ? 1.1 : 1) )
                
            case .wiggle:
                content
                    .rotationEffect(animation ? .degrees(-5) : .degrees(active ? 5 : 0))
                
            case .pop:
                content
                    .scaleEffect(animation ? 1.01 : (active ? 0.1 : 1))
                   
            }
        }
        .animation(getAnimation(), value: animation)
        .onAppear { startAnimation(self.active) }
        .onChange(of: active, perform: { value in startAnimation(active)})
    }
    
    private func getAnimation() -> Animation {
        
        switch type {
        case .expand: return Animation.linear(duration: 0.2)
        case .pop: return Animation.interpolatingSpring(mass: 1,stiffness: 300,damping: 10,initialVelocity: 10)
        case .wiggle: return Animation.linear(duration: 0.1)
        }
        
    }
    
    func startAnimation(_ active: Bool) {
        
        //let animType = getAnimation().repeatForever()
        
        if active {
            //withAnimation(animType) {
                animation = true
            //}
            if duration != 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(.easeIn) {
                        animation = false
                        self.active = false
                    }
                }
            }
        } else {
            withAnimation(.easeIn) {
                animation = false
            }
            self.active = false
        }
    }
}


