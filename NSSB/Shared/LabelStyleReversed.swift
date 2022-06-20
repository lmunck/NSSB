//
//  LabelStyleReversed.swift
//  NSSB
//
//  Created by Anders Munck on 03/06/2022.
//

import SwiftUI




struct LabelStyleReversed: LabelStyle {
    
    
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            
            configuration.title
            
            Spacer()
            configuration.icon
            
            
            
        }
    }
}
