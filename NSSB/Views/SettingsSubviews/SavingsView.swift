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
    
    @State private var tempCost:Double = 0
    
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
                    
                    TextField("0", value: $tempCost, format: .currency(code: "\(Locale.current.currency?.identifier ?? "")"))
                        .keyboardType(.decimalPad)
                        .onSubmit {
                            self.costPer20 = tempCost
                        }
                        .focused($textfieldFocused)
                    
                        // Select the existing amount on focus so typing replaces it
                        // instead of appending to the formatted "0,00" placeholder,
                        // and commit the value whenever focus is lost - not only
                        // when the Done button is used.
                        .onChange(of: textfieldFocused) { isFocused in
                            if isFocused {
                                DispatchQueue.main.async {
                                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                                }
                            } else if self.costPer20 != tempCost {
                                self.costPer20 = tempCost
                            }
                        }
                    
                    if keyboardVisible {
                        
                        Button("Done", action: {
                            self.costPer20 = tempCost
                            textfieldFocused = false
                        })
                        
                    }
                }
                .foregroundStyle(Color.accent)
                .padding(3)
                .background( Rectangle().fill(.black).cornerRadius(3))
                    
            }
            .onChange(of: self.costPer20) { newCost in
                if self.tempCost != costPer20 {
                    self.tempCost = costPer20
                }
            }
            .onAppear {
                self.tempCost = costPer20
            }
            .onReceive(keyboardPublisher) { newIsKeyboardVisible in
                keyboardVisible = newIsKeyboardVisible
            }
            
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        //.onAppear { saveStepSize(self.stepSize) }
    }
    
    
    
}

struct SavingsView_Previews: PreviewProvider {
    static var previews: some View {
        SavingsView(costPer20: .constant(20), returnAction: {})
    }
}
