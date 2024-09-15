//
//  ScoreView.swift
//  NSSB
//
//  Created by Anders Munck on 06/06/2022.
//

import SwiftUI

struct ScoreView: View, KeyboardReadable {
    
    var data:NonSmokingData
    
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
            
            if showAlternate || data.costPer20 == 0 {
                
                GridRow {
                    
                    VStack(spacing: -3) {
                        Text("\(data.breaksToday())").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    
                    VStack(spacing: -3) {
                        Text("\(data.breaksDailyAvg(), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    
                    VStack(spacing: -3) {
                        Text("\(data.breaksTotal())").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("Breaks")
                    }
                    
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                
                
            } else {
                
                GridRow {
                    
                    VStack(spacing: -3) {
                        Text("\(data.savingsToday(), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    
                    VStack(spacing: -3) {
                        Text("\(data.savingsDailyAvg(), specifier: "%.1f")").foregroundColor(.white)
                            .font(.largeTitle)
                        Text("\(Locale.current.currency?.identifier ?? "")")
                    }
                    
                    VStack(spacing: -3) {
                        Text("\(data.savingsTotal(), specifier: "%.0f")").foregroundColor(.white)
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
        ScoreView(data: NonSmokingData.example).foregroundStyle(.gray).background(.black)
    }
}

