//
//  ScoreView.swift
//  NSSB
//
//  Created by Anders Munck on 06/06/2022.
//

import SwiftUI

struct ScoreView: View {
    
    var data:NonSmokingData
    
    //@State private var perPack:Double = UserDefaults.standard.double(forKey: "perPackCosts")
    @State private var showAlternate:Bool = false
    
    
    var body: some View {
        
        GeometryReader { geo in
            
            VStack {
                
                Spacer()
                
                VStack(spacing: 0) {
                    
                    HStack(spacing: -3) {
                        
                        Text("Today")
                            .frame(width: geo.size.width/3)
                        
                        
                        Text("Daily average")
                            .frame(width: geo.size.width/3)
                        
                        
                        Text("All time")
                            .frame(width: geo.size.width/3)
                        
                    }
                    .font(.footnote)
                    
                    if showAlternate == (data.costPer20 != 0) || data.costPer20 == 0 {
                        
                        // Breaks
                        HStack(spacing: 0) {
                            
                            VStack(spacing: -3) {
                                Text("\(data.breaksToday())").foregroundColor(.white)
                                    .font(.largeTitle)
                                Text("Breaks")
                            }
                            .frame(width: geo.size.width/3)
                            
                            VStack(spacing: -3) {
                                Text("\(data.breaksDailyAvg(), specifier: "%.1f")").foregroundColor(.white)
                                    .font(.largeTitle)
                                Text("Breaks")
                            }
                            .frame(width: geo.size.width/3)
                            
                            VStack(spacing: -3) {
                                Text("\(data.breaksTotal())").foregroundColor(.white)
                                    .font(.largeTitle)
                                Text("Breaks")
                            }
                            .frame(width: geo.size.width/3)
                            
                        }
                        .font(.footnote)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                    } else {
                        
                        // Savings
                        HStack(spacing: 0) {
                            
                            VStack(spacing: -3) {
                                Text("\(data.savingsToday(), specifier: "%.1f")").foregroundColor(.white)
                                    .font(.largeTitle)
                                Text("\(Locale.current.currencyCode ?? "")")
                            }
                            .frame(width: geo.size.width/3)
                            
                            VStack(spacing: -3) {
                                Text("\(data.savingsDailyAvg(), specifier: "%.1f")").foregroundColor(.white)
                                    .font(.largeTitle)
                                Text("\(Locale.current.currencyCode ?? "")")
                            }
                            .frame(width: geo.size.width/3)
                            
                            VStack(spacing: -3) {
                                Text("\(data.savingsTotal(), specifier: "%.0f")").foregroundColor(.white)
                                    .font(.largeTitle)
                                Text("\(Locale.current.currencyCode ?? "")")
                            }
                            .frame(width: geo.size.width/3)
                            
                        }
                        .font(.footnote)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showAlternate)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 10, pressing: { inProgress in
                    if inProgress { showAlternate = true } else { showAlternate = false }
                    }) {
                        showAlternate = false
                    }
                
            }
        }
    }
}

struct ScoreView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreView(data: NonSmokingData())
    }
}

