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
                    
                    
                    // The disclosure. Almost nobody reads an info panel, so
                    // the feeling of a populated courtyard survives - but the
                    // app is never making a claim it has not written down.
                    VStack(alignment: .leading, spacing: 10) {
                        
                        Text("The courtyard").font(.headline)
                        
                        Text("While your cigarette burns, you can see everyone else whose cigarette is burning too. Their design, the name they rolled, a flag from their phone's region, and what time it is where they are. Nothing else, and no way to reach them afterwards.")
                        
                        Text("When your cigarette goes out, so does all of it. Nothing is kept about who you stood next to.")
                        
                        Text("If the courtyard is quiet, you may still see a few faint cigarettes burned down to the filter. Those are embers - real breaks that real people finished within the last hour, left glowing a little longer so the place is never completely dark. They are not people standing there now, and they are drawn dimmer and shorter because of it.")
                    }
                    
                    
                    VStack(alignment: .leading, spacing: 10) {
                        
                        Text("Got a light?").font(.headline)
                        
                        Text("Before you light up, you can ask the courtyard for a light. The ask goes out to everyone whose cigarette is burning - never to one person, so nobody is singled out and nobody has to turn anybody down.")
                        
                        Text("Whoever answers first lights your cigarette, and the two tips touch. If nobody answers within eight seconds, you light your own, which is what happens most times in real life anyway.")
                        
                        Text("While you are lit you will see anyone out there standing with an unlit cigarette, waiting. Giving them a light costs you nothing, takes nothing off your own cigarette, and tells them no more about you than the courtyard already does. There is still no way to reach anybody, before or afterwards.")
                    }
                    
                    
                    VStack(alignment: .leading, spacing: 10) {
                        
                        Text("v1.3 Update").font(.headline)
                        
                        Text("Thankyouthankyouthankyou for all your downloads and great feedback!")
                        
                        Text("You are no longer out there alone: the courtyard shows who else is on a non-smoking break right now, and you can ask for a light or give one.")
                        
                        Text("Your iPhone and Apple Watch now actually agree with each other. Breaks and settings sync even when one of them is asleep.")
                        
                        Text("New watch complication: today's breaks, or how far into a break you are, right on your watch face. And a few pesky bugs have been sent outside for a long, smoke-free break.")
                        
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
        InfoView(menu: .constant(.info), data: NonSmokingData.example)
    }
}

