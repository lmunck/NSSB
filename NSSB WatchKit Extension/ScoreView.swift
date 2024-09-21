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
                        if #available(watchOS 9, *) {
                            Text("\(Locale.current.currency?.identifier ?? "")")
                        } else {
                            Text("")
                        }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                
            }
            .background()
            .contentShape(Rectangle())
            .onTapGesture {
                showAlternate.toggle()
            }
            
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
                        if #available(watchOS 9, *) {
                            Text("\(Locale.current.currency?.identifier ?? "")")
                        } else {
                            Text("")
                        }
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
        }
        .font(.footnote)
        .animation(.easeInOut(duration: 0.4), value: showAlternate)
        
    }
}

#Preview {
    ScoreView(breaks: NonSmokingData.example.breaks, costPer20: NonSmokingData.example.costPer20)
}
