//
//  CourtyardCountView.swift
//  NSSB
//

// Layer 0 of the shared smoke break: one line, telling you whether anyone
// else is out there.
//
// It never shows a zero. "0 people online" is a dead screen and an invitation
// to close the app; "quiet out here right now" is the same fact told in a way
// that still sounds like somewhere worth standing.

import SwiftUI

struct CourtyardCountView: View {
    
    @EnvironmentObject var presence: PresenceRepository
    
    var body: some View {
        
        Text(line)
            .font(.footnote)
            .foregroundStyle(.gray)
            .animation(.easeInOut(duration: 0.4), value: line)
            // Nothing at all until we have actually looked. Claiming an empty
            // courtyard before the first query would be a guess.
            .opacity(presence.othersCount == nil ? 0 : 1)
    }
    
    private var line: String {
        
        guard let others = presence.othersCount else { return " " }
        
        switch others {
        case 0:  return "quiet out here right now"
        case 1:  return "1 other is out here"
        default: return "\(others) others are out here"
        }
    }
}

#Preview {
    CourtyardCountView()
        .environmentObject(PresenceRepository())
        .background(.black)
}
