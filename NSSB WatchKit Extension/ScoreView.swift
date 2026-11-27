//
//  ScoreView.swift
//  NSSB WatchKit App
//
//  Created by Anders Munck on 05/08/2024.
//

import SwiftUI

struct ScoreView: View {
    
    let breaks:[Date]
    let costPer20:Double
    
    @State private var showAlternate:Bool = false
    
    private var currency: String { Locale.current.currency?.identifier ?? "" }

    /// The two columns swap between breaks and money together, on the same
    /// condition the views below use.
    private var showingSavings: Bool { costPer20 != 0 && showAlternate }

    private var todaySpoken: String {
        showingSavings
        ? "Today, \(String(format: "%.0f", breaks.savingsToday(costPer20: costPer20))) \(currency) saved"
        : "Today, \(breaks.breaksToday()) breaks"
    }

    private var totalSpoken: String {
        showingSavings
        ? "Total, \(String(format: "%.0f", breaks.savingsTotal(costPer20: costPer20))) \(currency) saved"
        : "Total, \(breaks.breaksTotal()) breaks"
    }

    var body: some View {
        HStack {
            
            VStack(alignment: .leading, spacing: -5) {
                Text("Today")
                
                if costPer20 == 0 || showAlternate == false {
                    VStack(alignment: .leading, spacing: -5) {
                        Text("\(breaks.breaksToday())")
                            .font(.largeTitle).foregroundColor(.white)
                        Text("Breaks")
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    VStack(alignment: .leading, spacing: -5) {
                        Text("\(breaks.savingsToday(costPer20: costPer20), specifier: "%.0f")")
                            .font(.largeTitle).foregroundColor(.white)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                
            }
            .background()
            .contentShape(Rectangle())
            .onTapGesture {
                showAlternate.toggle()
            }
            // Heading, figure and unit are three separate scraps otherwise,
            // and the tap that swaps them is invisible.
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(todaySpoken)
            .accessibilityHint("Switches between breaks and money saved")
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: -5) {
                Text("Total")
                
                if costPer20 == 0 || showAlternate == false {
                    VStack(alignment: .trailing, spacing: -5) {
                        Text("\(breaks.breaksTotal())")
                            .font(.largeTitle).foregroundColor(.white)
                        Text("Breaks")
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    VStack(alignment: .trailing, spacing: -5) {
                        Text("\(breaks.savingsTotal(costPer20: costPer20), specifier: "%.0f")")
                            .font(.largeTitle).foregroundColor(.white)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .background()
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 10, pressing: { inProgress in
                if inProgress { showAlternate = true } else { showAlternate = false }
                }) {
                    showAlternate = false
                }
            // The press-and-hold is not offered to VoiceOver: a ten second
            // hold is not a gesture it can pass on, and the same figures are
            // a tap away on the other column.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(totalSpoken)
        }
        .font(.footnote)
        .animation(.easeInOut(duration: 0.4), value: showAlternate)
        
    }
}

#Preview {
    ScoreView(breaks: NonSmokingData.example.breaks, costPer20: NonSmokingData.example.costPer20)
}
