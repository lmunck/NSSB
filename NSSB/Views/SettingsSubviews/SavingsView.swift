//
//  SavingsView.swift
//  NSSB
//
//  Created by Anders Munck on 17/06/2022.
//

import SwiftUI

struct SavingsView: View, KeyboardReadable {
    
    @Binding var costPer20:Double
    var returnAction: () -> Void
    
    @State private var keyboardVisible:Bool = false
    
    @FocusState private var textfieldFocused: Bool
    //@State var costPerPack:Double = UserDefaults.standard.double(forKey: "perPackCosts")
    //@State var stepSize:Double = UserDefaults.standard.double(forKey: "stepSize")
    //let stepSizeArray:[Double] = [0.1, 1, 10, 100, 1000]
    
    var body: some View {
        VStack(spacing: 5) {
            
            Label("Cost saved", systemImage: "dollarsign.circle")
                    .labelStyle(LabelStyleReversed())
                    .font(.title)
                    .onTapGesture { returnAction() }
            
                
            VStack(alignment: .leading, spacing: 3) {
                   
                Text("Cost of 20 cigarettes").font(.footnote)
                
                // Cost
                HStack(alignment: .bottom, spacing: 2) {
                    
                    TextField("0", value: $costPer20, format: .currency(code: "\(Locale.current.currency?.identifier ?? "")"))
                        .keyboardType(.decimalPad)
                        .focused($textfieldFocused)
                    
                    if keyboardVisible {
                        
                        Button("Done", action: { textfieldFocused = false })
                        
                    }
                }.foregroundStyle(Color.accent)
                    
            }.onReceive(keyboardPublisher) { newIsKeyboardVisible in
                keyboardVisible = newIsKeyboardVisible
            }
            
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        //.onAppear { saveStepSize(self.stepSize) }
    }
    
    func updateCosts(_ perPack: Double) {
        
        // Round to nearest tenth
        //let perPack = round(perPack * 10) / 10.0
        
        // If value changed
        if perPack != UserDefaults.standard.double(forKey: "perPackCosts") {
            
            // Save new value
            UserDefaults.standard.set(perPack, forKey: "perPackCosts")
            
        } else {
            
            return
            
        }
    }
    
    /*func saveStepSize(_ stepSize: Double) {
        
        // Round to nearest tenth
        //let perPack = round(perPack * 10) / 10.0
        
        // Check if stepSize too small
        var stepSize = stepSize
        if stepSize <= 0 {
            stepSize = 1
            self.stepSize = stepSize
        }
        
        // If value changed
        if stepSize != UserDefaults.standard.double(forKey: "stepSize") {
            
            // Save new value
            UserDefaults.standard.set(stepSize, forKey: "stepSize")
            
        } else {
            
            return
            
        }
    }*/
}

struct SavingsView_Previews: PreviewProvider {
    static var previews: some View {
        SavingsView(costPer20: .constant(20), returnAction: {})
    }
}


struct CustomStepper: View {
    
    @Binding var perPack:Double
    let stepSize:Double
    //var editingChanged: (Bool) -> Void
    
    init(_ perPack: Binding<Double>, stepSize: Double) {
        
        self._perPack = perPack
        self.stepSize = stepSize
        //self.editingChanged = editingChanged
        
        // Custom icons so I can control color with foregroundcolor
            UIStepper.appearance().setDecrementImage(UIImage(systemName: "minus"), for: .normal)
            UIStepper.appearance().setIncrementImage(UIImage(systemName: "plus"), for: .normal)
        
    }
    
    var body: some View {
        Stepper("", value: $perPack, in: 0...1000000, step: stepSize)
    }
}
