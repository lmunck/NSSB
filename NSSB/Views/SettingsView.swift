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
            
            HStack {
                
                Spacer()
                
                Label("Settings", systemImage: menu == .settings ? "gearshape.fill" : "gearshape")
                    .labelStyle(.iconOnly)
                    .font(.largeTitle)
                    .foregroundColor(.accent)
                    .padding()
                    .contentShape(Rectangle())
                    .onTapGesture { returnAction() }
                
            }
            
            if menu == .settings {
                
                VStack(spacing:30) {
                    
                    ReminderView(returnAction: returnAction)
                    
                    SavingsView(costPer20: $data.costPer20, returnAction: returnAction)
                    
                    SettingsColorView(design: $data.cigDesign, returnAction: returnAction)
                    //ColorPickerView()
                }
                .padding()
                .transition(.move(edge: .trailing))
                
            }
            
            Spacer()
                .onTapGesture {
                    returnAction()
                }
            
        }
        
    }
    
    func returnAction() {
        if menu == .settings { menu = .cigarette } else { menu = .settings }
    }
    
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(menu: .constant(.settings), data: .constant(NonSmokingData()))
    }
}

