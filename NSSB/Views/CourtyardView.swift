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
import Combine

struct CourtyardView: View {
    
    let others: [BreakPresence]
    
    /// Breaks that have already ended. Drawn as what they are - cigarettes
    /// burned down to the filter, very dim - rather than dressed up as people
    /// who are still here. The courtyard is never completely dark, and
    /// nothing on screen claims someone is present who is not.
    let echoes: [BreakPresence]
    
    /// People standing out here with an unlit cigarette, asking.
    ///
    /// Drawn last, over everyone else, because an ask is the one thing in
    /// this courtyard that wants answering.
    let asks: [BreakAsk]
    
    /// People standing out here unlit, waiting for somebody to start with.
    ///
    /// Only ever populated while you are waiting too - which is also the only
    /// time any of this is on screen before your own cigarette is lit.
    let waits: [BreakWait]
    
    /// The height of your own cigarette, which everything else is sized
    /// against so the courtyard scales with the screen.
    let referenceHeight: CGFloat
    
    /// Ticks so the distant cigarettes burn down rather than freezing at the
    /// position they had when the snapshot arrived.
    @State private var now: Date = .now
    private let clock = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    @Binding var selected: BreakPresence?
    
    /// Tapping somebody who is asking gives them a light. There is no card
    /// and no second button: you had to aim at an unlit cigarette that is
    /// visibly asking, and that is the decision made.
    let offer: (BreakAsk) -> Void
    
    /// Tapping somebody who is waiting takes the chair beside them.
    let join: (BreakWait) -> Void
    
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
                
                // Same clock filter as the asks below, for the same
                // reason: thirty seconds is shorter than the listener's
                // lifetime, so a waiter whose owner never came back to
                // delete the document would otherwise stand there forever.
                ForEach(waits.filter { $0.isOpen(at: now) }) { wait in
                    
                    let spot = Courtyard.position(for: wait.id)
                    
                    WaitingCigaretteView(
                        wait: wait,
                        height: referenceHeight * (0.17 + spot.depth * 0.25)
                    )
                    .position(
                        x: geo.size.width * spot.x,
                        y: geo.size.height * spot.y
                    )
                    .onTapGesture { join(wait) }
                    .transition(.opacity)
                }
                
                // Filtered by the clock as well as by the query. The
                // courtyard listener's range was fixed when it attached, so
                // an ask whose owner never came back to delete it would
                // otherwise stand there asking forever; this way it goes out
                // within a tick of its eight seconds either way.
                ForEach(asks.filter { $0.isOpen(at: now) }) { ask in
                    
                    let spot = Courtyard.position(for: ask.id)
                    
                    AskingCigaretteView(
                        ask: ask,
                        height: referenceHeight * (0.17 + spot.depth * 0.25)
                    )
                    .position(
                        x: geo.size.width * spot.x,
                        y: geo.size.height * spot.y
                    )
                    .onTapGesture { offer(ask) }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.6), value: others.map(\.id))
            .animation(.easeInOut(duration: 0.4), value: asks.map(\.id))
            .animation(.easeInOut(duration: 0.5), value: waits.map(\.id))
        }
        .allowsHitTesting(true)
        .onReceive(clock) { now = $0 }
    }
}

/// Somebody standing out here with an unlit cigarette.
///
/// A dark cigarette in a dark courtyard is almost nothing to look at, which
/// is the problem: it has eight seconds to be noticed. So it breathes - a
/// halo in their own accent colour, widening and fading, the way you notice
/// somebody shifting their weight across a car park rather than the way you
/// notice an alarm.
///
/// Nothing warm anywhere near the tip. Their cigarette is not lit, and the
/// whole point of the next few seconds is that it could be.
struct AskingCigaretteView: View {
    
    let ask: BreakAsk
    let height: CGFloat
    
    @State private var breath: Double = 0
    
    /// Runs down with the ask itself, so the halo is at its most visible the
    /// moment the question is asked and has almost nothing left by the time
    /// it goes unanswered. Driven by the document's own expiresAt rather than
    /// by a timer, so it is honest about how long is actually left.
    @State private var left: Double = 1
    
    var body: some View {
        
        ZStack {
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [ask.design.background.opacity(0.5), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: height * 0.42
                    )
                )
                .frame(width: height * 0.9, height: height * 0.9)
                .scaleEffect(0.8 + breath * 0.35)
                .opacity((0.45 + breath * 0.55) * left)
                .blur(radius: height * 0.05)
            
            DistantCigaretteView(
                design: ask.design,
                progress: 0,
                height: height,
                lit: false
            )
            // Dimmer than a lit stranger, because there is no ember to carry
            // it - but never so dim that it is a smudge.
            .opacity(0.45 + 0.3 * left)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                breath = 1
            }
            withAnimation(.easeIn(duration: max(ask.expiresAt.timeIntervalSinceNow, 0.2))) {
                left = 0
            }
        }
    }
}

/// Somebody standing out here unlit, waiting for company.
///
/// Deliberately not the asking cigarette. An ask has eight seconds and wants
/// something, so it breathes and has to be noticed. Waiting is not urgent and
/// is not a request - it is somebody leaning on a wall - so this one holds
/// still. A single soft aura, no pulse, and a slow fade as the thirty seconds
/// go, which is the only thing about it that moves.
///
/// Nothing warm near the tip on either of them. Both cigarettes are unlit,
/// and in this one's case that is the whole invitation: it could be lit at the
/// same moment as yours.
struct WaitingCigaretteView: View {
    
    let wait: BreakWait
    let height: CGFloat
    
    @State private var left: Double = 1
    
    var body: some View {
        
        ZStack {
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [wait.design.background.opacity(0.32), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: height * 0.5
                    )
                )
                .frame(width: height, height: height)
                .opacity(0.35 + 0.35 * left)
                .blur(radius: height * 0.06)
            
            DistantCigaretteView(
                design: wait.design,
                progress: 0,
                height: height,
                lit: false
            )
            .opacity(0.42 + 0.3 * left)
        }
        .onAppear {
            // Driven by the document's own expiresAt, so it is honest about
            // how much of the wait is left even if this device saw it late.
            withAnimation(.easeInOut(duration: max(wait.expiresAt.timeIntervalSinceNow, 0.2))) {
                left = 0
            }
        }
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
                DaylightView(daylight: presence.daylight())
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

extension CourtyardStranger {
    
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

/// Where somebody is in their own day, as one small symbol.
///
/// Sits where their clock used to. A time of day gets read against your own
/// and, next to a cigarette already counting down, looked like a second
/// timer. A sun or a moon is the part you actually wanted: somebody is out
/// here in the dark, or on their lunch, or before work.
struct DaylightView: View {
    
    let daylight: Daylight
    
    var body: some View {
        Image(systemName: daylight.symbol)
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel(daylight.spoken)
    }
}
