//
//  CourtyardView.swift
//  NSSB
//

// Layer 1: the people who are also outside right now.
//
// Their cigarettes stand behind yours, each at its own true burn position, so
// the room reads at a glance - a short cigarette is someone nearly finished,
// a long one is someone who just lit up. No chat, no names until you tap one.

import SwiftUI

struct CourtyardView: View {
    
    let others: [BreakPresence]
    
    /// Breaks that have already ended. Drawn as what they are - cigarettes
    /// burned down to the filter, very dim - rather than dressed up as people
    /// who are still here. The courtyard is never completely dark, and
    /// nothing on screen claims someone is present who is not.
    let echoes: [BreakPresence]
    
    /// The height of your own cigarette, which everything else is sized
    /// against so the courtyard scales with the screen.
    let referenceHeight: CGFloat
    
    /// Ticks so the distant cigarettes burn down rather than freezing at the
    /// position they had when the snapshot arrived.
    @State private var now: Date = .now
    private let clock = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    @Binding var selected: BreakPresence?
    
    var body: some View {
        
        GeometryReader { geo in
            
            ZStack {
                
                ForEach(echoes) { ember in
                    
                    let spot = Courtyard.position(for: ember.id)
                    
                    DistantCigaretteView(
                        design: ember.design,
                        progress: 1,
                        height: referenceHeight * (0.14 + spot.depth * 0.16)
                    )
                    .opacity(0.16)
                    .position(
                        x: geo.size.width * spot.x,
                        y: geo.size.height * spot.y
                    )
                    .allowsHitTesting(false)
                }
                
                ForEach(others) { other in
                    
                    let spot = Courtyard.position(for: other.id)
                    let height = referenceHeight * (0.17 + spot.depth * 0.25)
                    
                    DistantCigaretteView(
                        design: other.design,
                        progress: other.progress(at: now),
                        height: height
                    )
                    // Further away is dimmer. Nobody in the background should
                    // compete with the cigarette in your hand - but they do
                    // have to read as lit cigarettes rather than grey marks,
                    // so the floor is high enough for the ember to carry.
                    .opacity(0.38 + spot.depth * 0.4)
                    .position(
                        x: geo.size.width * spot.x,
                        y: geo.size.height * spot.y
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selected = (selected?.id == other.id) ? nil : other
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: others.map(\.id))
        }
        .allowsHitTesting(true)
        .onReceive(clock) { now = $0 }
    }
}

/// Where a given break stands.
///
/// Derived from the break id rather than from its position in the array, so a
/// cigarette keeps its spot as other people come and go. A snapshot arriving
/// must not make the whole courtyard rearrange itself.
enum Courtyard {
    
    static func position(for id: String) -> (x: Double, y: Double, depth: Double) {
        
        var hash: UInt64 = 5381
        for byte in id.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        
        func slice(_ shift: UInt64) -> Double {
            Double((hash >> shift) & 0xFFFF) / Double(0xFFFF)
        }
        
        let depth = slice(32)
        
        // Pushed away from the centre column, where your own cigarette is.
        // Without this the nearest strangers stand exactly where you do.
        let raw = slice(0)
        let side: Double = raw < 0.5 ? 0 : 1
        let offset = abs(raw - 0.5) * 2
        let x = side == 0
            ? 0.06 + offset * 0.26
            : 0.68 + offset * 0.26
        
        // Further away sits higher up the screen.
        let y = 0.12 + slice(16) * 0.5 + (1 - depth) * 0.12
        
        return (x, y, depth)
    }
}

/// What you learn by tapping a stranger's cigarette.
///
/// Name, where they are to the nearest country, and what time it is there.
/// Not their city, not their distance, not how many breaks they have taken -
/// and there is nothing here to tap through to. You can recognise someone
/// without being able to reach them.
struct CourtyardDetailView: View {
    
    let presence: BreakPresence
    
    var body: some View {
        
        VStack(spacing: 2) {
            
            Text(presence.name)
                .font(.headline)
                .foregroundStyle(.white)
            
            HStack(spacing: 6) {
                if let flag = presence.flag {
                    Text(flag)
                }
                Text("\(presence.localTimeString()) there")
            }
            .font(.footnote)
            .foregroundStyle(.gray)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

extension BreakPresence {
    
    /// A flag from the region code, never from GPS. Nil when they chose not
    /// to say, or when the code is not a region we can render.
    var flag: String? {
        
        guard let country = country, country.count == 2 else { return nil }
        
        let base: UInt32 = 127397
        var scalars = String.UnicodeScalarView()
        for ch in country.uppercased().unicodeScalars {
            guard let scalar = UnicodeScalar(base + ch.value) else { return nil }
            scalars.append(scalar)
        }
        
        return String(scalars)
    }
}
