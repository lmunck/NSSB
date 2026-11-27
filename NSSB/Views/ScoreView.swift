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
    
    private var currency: String { Locale.current.currency?.identifier ?? "" }

    var body: some View {
        
        Grid(verticalSpacing: -3) {
            // Read as part of each figure below instead. On their own they
            // are three words in a row with nothing attached to them.
            GridRow {
                
                Text("Today").frame(maxWidth: .infinity)
                Text("Daily average").frame(maxWidth: .infinity)
                Text("All time").frame(maxWidth: .infinity)
                
            }
            .accessibilityHidden(true)
            
            if showAlternate || costPer20 == 0 {
                
                GridRow {
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.breaksToday())").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    // A figure and a unit in one breath, with the column
                    // it belongs to, because the heading above it is not
                    // read alongside it.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Today, \(breaks.breaksToday()) breaks")
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.breaksDailyAvg(), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    // A figure and a unit in one breath, with the column
                    // it belongs to, because the heading above it is not
                    // read alongside it.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Daily average, \(String(format: "%.1f", breaks.breaksDailyAvg())) breaks")
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.breaksTotal())").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    // A figure and a unit in one breath, with the column
                    // it belongs to, because the heading above it is not
                    // read alongside it.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("All time, \(breaks.breaksTotal()) breaks")
                    
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                
            } else {
                
                GridRow {
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.savingsToday(costPer20: costPer20), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    // A figure and a unit in one breath, with the column
                    // it belongs to, because the heading above it is not
                    // read alongside it.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Today, \(String(format: "%.1f", breaks.savingsToday(costPer20: costPer20))) \(currency) saved")
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.savingsDailyAvg(costPer20: costPer20), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    // A figure and a unit in one breath, with the column
                    // it belongs to, because the heading above it is not
                    // read alongside it.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Daily average, \(String(format: "%.1f", breaks.savingsDailyAvg(costPer20: costPer20))) \(currency) saved")
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.savingsTotal(costPer20: costPer20), specifier: "%.0f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    // A figure and a unit in one breath, with the column
                    // it belongs to, because the heading above it is not
                    // read alongside it.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("All time, \(String(format: "%.0f", breaks.savingsTotal(costPer20: costPer20))) \(currency) saved")
                    
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

