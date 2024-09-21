//
//  ScoreView.swift
//  NSSB
//
//  Created by Anders Munck on 06/06/2022.
//

import SwiftUI

struct ScoreView: View, KeyboardReadable {
    
    let breaks: [Date]
    let costPer20: Double
    
    //@State private var perPack:Double = UserDefaults.standard.double(forKey: "perPackCosts")
    @State private var showAlternate:Bool = false
    
    @State private var keyboardVisible:Bool = false
    
    var body: some View {
        
        Grid(verticalSpacing: -3) {
            GridRow {
                
                Text("Today").frame(maxWidth: .infinity)
                Text("Daily average").frame(maxWidth: .infinity)
                Text("All time").frame(maxWidth: .infinity)
                
            }
            
            if showAlternate || costPer20 == 0 {
                
                GridRow {
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.breaksToday())").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.breaksDailyAvg(), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.count)").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                
            } else {
                
                GridRow {
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.savingsToday(costPer20: costPer20), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.savingsDailyAvg(costPer20: costPer20), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.savingsTotal(costPer20: costPer20), specifier: "%.0f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .font(.footnote)
        .animation(.easeInOut(duration: 0.4), value: showAlternate)
        .contentShape(Rectangle())
        .opacity(keyboardVisible ? 0 : 1)
        .onTapGesture {
            showAlternate.toggle()
        }
        .onReceive(keyboardPublisher) { newIsKeyboardVisible in
            keyboardVisible = newIsKeyboardVisible
        }
        
    }
    
    
    
}

struct ScoreView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreView(breaks: NonSmokingData.example.breaks, costPer20: NonSmokingData.example.costPer20).foregroundStyle(.gray).background(.black)
    }
}

