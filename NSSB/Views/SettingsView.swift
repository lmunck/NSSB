//
//  IntroductionView.swift
//  NSSB
//
//  Created by Anders Munck on 29/05/2022.
//

import SwiftUI

struct SettingsView: View {
    
    @Binding var menu:AppMenu
    @Binding var data:NonSmokingData
    
    var body: some View {
        
        VStack(spacing: 10) {
            
            ScrollView(.vertical) {
                
                VStack(spacing:30) {
                    
                    ReminderView(returnAction: returnAction)
                    
                    SavingsView(costPer20: $data.costPer20, returnAction: returnAction)
                    
                    SettingsDesignView(design: $data.cigDesign, returnAction: returnAction)
                }
                
            }
            
            Spacer()
            
        }
        
    }
    
    func returnAction() {
        menu = .cigarette
    }
    
    
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(menu: .constant(.info), data: .constant(NonSmokingData.example))
    }
}

