//
//  MenuView.swift
//  NSSB
//
//  Created by Anders Munck on 16/08/2024.
//

import SwiftUI

struct MenuView: View {
    
    @Binding var data:NonSmokingData
    
    var body: some View {
        
        GeometryReader { geo in
            
            let buttonSize = geo.size.width / 5
            
            VStack {
                
                Spacer()
                
                HStack {
                    Label("", systemImage: "wand.and.stars")
                        .labelStyle(.iconOnly)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(
                            Color.white
                                .opacity(0.15)
                                .cornerRadius(buttonSize/2)
                                .frame(width: buttonSize, height: buttonSize * 1.3)
                        )
                        .onTapGesture {
                            
                            // Always a fresh cigarette, never a reset.
                            //
                            // This used to toggle between the standard design
                            // and a random one, which meant every other tap
                            // emptied the title. That was harmless when a name
                            // was decoration; now the name is the identity a
                            // stranger sees in the courtyard, and silently
                            // clearing it is not something a randomise button
                            // should do.
                            var fresh = getRandom()
                            while fresh.title == data.cigDesign.title {
                                fresh = getRandom()
                            }
                            self.data.cigDesign = fresh
                        }
                    
                    Spacer()
                    
                    if let cigURL = data.cigDesign.encodeURL() {
                        
                        ShareLink(item: cigURL, subject: Text("Try my custom non-smoke"), message: Text("Have a non-smoking smoke break with my custom non-smoking smoke\(data.cigDesign.title.isEmpty ? "." : ": \(data.cigDesign.title)")"), label: {
                            Text(Image(systemName: "square.and.arrow.up"))
                        }).frame(width: buttonSize, height: buttonSize)
                    } else {
                        EmptyView().frame(width: buttonSize, height: buttonSize)
                    }
                }
                
            }.foregroundStyle(Color.accent)
            
        }
        
        
    }
}

#Preview {
    MenuView(data: .constant(NonSmokingData.example))
}
