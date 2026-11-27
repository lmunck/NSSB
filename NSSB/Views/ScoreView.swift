//
//  ScoreView.swift
//  NSSB
//
//  Created by Anders Munck on 06/06/2022.
//

import SwiftUI

private extension View {

    /// One score cell: the figure said in a single breath, and the tap that
    /// swaps the whole row between breaks and money.
    ///
    /// That tap lives on the grid, behind these cells. Once each cell is an
    /// accessibility element of its own there is nothing left for VoiceOver
    /// to land on that would reach it, so each cell carries it instead.
    func scoreCell(_ label: String, toggle: @escaping () -> Void) -> some View {
        self.accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Switches between breaks and money saved")
            .accessibilityAction(.default, toggle)
    }
}

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
                    .scoreCell("Today, \(breaks.breaksToday()) breaks") { showAlternate.toggle() }
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.breaksDailyAvg(), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    .scoreCell("Daily average, \(String(format: "%.1f", breaks.breaksDailyAvg())) breaks") { showAlternate.toggle() }
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.breaksTotal())").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    .scoreCell("All time, \(breaks.breaksTotal()) breaks") { showAlternate.toggle() }
                    
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                
            } else {
                
                GridRow {
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.savingsToday(costPer20: costPer20), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    .scoreCell("Today, \(String(format: "%.1f", breaks.savingsToday(costPer20: costPer20))) \(currency) saved") { showAlternate.toggle() }
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.savingsDailyAvg(costPer20: costPer20), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    .scoreCell("Daily average, \(String(format: "%.1f", breaks.savingsDailyAvg(costPer20: costPer20))) \(currency) saved") { showAlternate.toggle() }
                    
                    VStack(spacing: -3) {
                        Text("\(breaks.savingsTotal(costPer20: costPer20), specifier: "%.0f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    .scoreCell("All time, \(String(format: "%.0f", breaks.savingsTotal(costPer20: costPer20))) \(currency) saved") { showAlternate.toggle() }
                    
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

