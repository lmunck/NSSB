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
                            if data.cigDesign.title != CigDesign.standard.title {
                                print("set standard")
                                self.data.cigDesign = CigDesign.standard
                            } else {
                                print("set random \(data.cigDesign.title)!=\(CigDesign.standard.title)")
                                self.data.cigDesign = getRandom()
                            }
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
