//
//  ScoreView.swift
//  NSSB
//
//  Created by Anders Munck on 01/06/2022.
//

import SwiftUI


struct InfoView: View {
    
    @Binding var menu:AppMenu
    var data:NonSmokingData
    
    var body: some View {
            ScrollView(.vertical) {
                
                VStack(alignment: .leading, spacing: 30) {
                    
                    VStack(alignment: .leading, spacing: 10) {
                        
                        Text("Cigarette breaks without smoke").font(.title)
                        
                        Text("Breaks are healthy but smoking kills you, so why not have one without the other?")
                        
                        Text("Non-Smoking Smoke Breaks let you relax, go outside, empty a coffee machine, breathe fresh air, and consider life choices without stressing your capillaries.")
                        
                        Text("Non-scientifically proven to have no impact on surgeon generals. May cause health benefits.")
                        
                    }
                    
                    
                    VStack(alignment: .leading, spacing: 10) {
                        
                        Text("v1.2 Update").font(.headline)
                        
                        Text("Thankyouthankyouthankyou for all your downloads and great feedback!")
                        
                        Text("New features include creating custom non-smokes and sharing them with friends, but I've also gotten rid of a few pesky bugs and hopefully made everything just a bit cooler.")
                        
                        Text("If you want to support, support a good cause, learn to code and give me a hand, or just scratch a dog behind the ear. I can be reached at nssb@nulkommafire.com.")
                        
                        Text("High fives, hip-bumps, and great breaks to all you non-smoking smoke breaking rock-stars.")
                        
                    }
                }
                .onTapGesture {
                    menu = .cigarette
                }
                .font(.body)
            }
            
            
        
        
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView(menu: .constant(.settings), data: NonSmokingData.example)
    }
}

