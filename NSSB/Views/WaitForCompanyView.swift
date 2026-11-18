//
//  WaitForCompanyView.swift
//  NSSB
//

// Layer 3, from the outside: stepping out and waiting for somebody to start
// with, then smoking next to them.
//
// Sits in the same row as "got a light?", in the same voice, and with the
// same shape of life: an offer, a drain, and a line that says what happened.
// The one difference is that this offer does not need anybody to be lit -
// you are waiting for somebody else who is also standing there unlit, and
// they do not show up in the count. It is the only social thing in the app
// that works in a courtyard with nobody in it.

import SwiftUI

struct WaitForCompanyView: View {
    
    let state: CompanyState
    
    /// Only an unlit cigarette can start together with anybody.
    let unlit: Bool
    
    /// True while the ask is doing something, so the two offers never both
    /// claim the row. Asking for a light and waiting for company are both
    /// things you do before lighting up, and doing both at once would mean
    /// two unlit cigarettes of yours standing in the same courtyard.
    let suppressed: Bool
    
    let wait: () -> Void
    
    /// Clears the line about nobody coming, so the offer can come back.
    let clear: () -> Void
    
    var body: some View {
        
        ZStack {
            
            switch state {
                
            case .idle:
                if unlit, suppressed == false {
                    Text("wait for someone")
                        .font(.footnote)
                        .foregroundStyle(Color.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().stroke(Color.accent.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.horizontal, 5)
                        .contentShape(Capsule())
                        .onTapGesture(perform: wait)
                        .transition(.opacity)
                }
                
            case .waiting(let outgoing):
                WaitingLineView(wait: outgoing)
                    .transition(.opacity)
                
            case .together(let companion, _):
                
                // For the whole five minutes, because this is who you are
                // standing with rather than something that just happened.
                // Their name, their flag and their clock - the same three
                // things a tapped stranger tells you, and nothing more.
                HStack(spacing: 6) {
                    Text("with \(companion.name)")
                    if let flag = companion.flag {
                        Text(flag)
                    }
                    Text("· \(companion.localTimeString()) there")
                }
                .font(.footnote)
                .foregroundStyle(.gray)
                .transition(.opacity)
                
            case .alone:
                Text("nobody came out - lighting your own")
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .transition(.opacity)
            }
        }
        .task(id: isAlone) {
            guard isAlone else { return }
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard Task.isCancelled == false else { return }
            clear()
        }
        .frame(height: 30)
        .animation(.easeInOut(duration: 0.3), value: state)
    }
    
    private var isAlone: Bool {
        if case .alone = state { return true }
        return false
    }
}

/// The thirty seconds, draining.
///
/// Thirty seconds of standing about is long enough to wonder whether the app
/// has forgotten you, so the bar is the reassurance that this ends by itself.
/// Slower and calmer than the ask's: asking is a question in flight, waiting
/// is just waiting.
private struct WaitingLineView: View {
    
    let wait: BreakWait
    
    @State private var left: Double = 1
    
    var body: some View {
        
        VStack(spacing: 5) {
            
            Text("waiting for company")
                .font(.footnote)
                .foregroundStyle(.gray)
            
            Capsule()
                .fill(Color.accent.opacity(0.7))
                .frame(width: 90 * left, height: 2)
                .frame(width: 90, alignment: .leading)
        }
        .onAppear {
            // From the document, not from now, so the bar tells the truth
            // about how long is actually left.
            withAnimation(.linear(duration: max(wait.expiresAt.timeIntervalSinceNow, 0.2))) {
                left = 0
            }
        }
    }
}

/// What you learn by tapping somebody who is waiting.
///
/// The same card as every other stranger's, with the second of the two
/// buttons in this app that do something to another person. Taking the chair
/// is not asking permission - the chair is free, and nobody is refused.
struct WaitDetailView: View {
    
    let wait: BreakWait
    let join: () -> Void
    
    var body: some View {
        
        VStack(spacing: 8) {
            
            VStack(spacing: 2) {
                
                Text(wait.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                HStack(spacing: 6) {
                    if let flag = wait.flag {
                        Text(flag)
                    }
                    Text("\(wait.localTimeString()) there")
                }
                .font(.footnote)
                .foregroundStyle(.gray)
            }
            
            Text("smoke with them")
                .font(.footnote)
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().stroke(Color.accent.opacity(0.6), lineWidth: 1)
                )
                .contentShape(Capsule())
                .onTapGesture(perform: join)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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

/// The person you are smoking with, standing next to your own cigarette.
///
/// Drawn from your own clock rather than from the network, which is the one
/// real dividend of starting together: you lit at the same instant, so their
/// burn position is your burn position for the whole five minutes and there
/// is nothing to keep in sync. Their cigarette goes out when yours does
/// because it was always going to.
struct CompanionCigaretteView: View {
    
    let companion: Companion
    
    /// Your own burn position, which is also theirs.
    let progress: Double
    
    let height: CGFloat

    /// Which side of you they are standing on. Their name hangs on the far
    /// side, so nothing is written in the gap between the two cigarettes.
    var mirrored: Bool = false

    private var design: CigDesign { companion.design }
    private var width: CGFloat { max(1, height * design.widthPercentage) }
    private var glowHeight: CGFloat { height * design.glowPercentage }
    private var filterHeight: CGFloat { height * design.filterPercentage }

    /// The body is what burns away, at your pace because it is your pace.
    private var bodyHeight: CGFloat {
        let full = (design.bodyPercentage + design.glowPercentage) * height - glowHeight
        return max(0, full - full * progress)
    }

    private var spacerHeight: CGFloat {
        max(0, height - (glowHeight + bodyHeight + filterHeight))
    }

    var body: some View {

        ZStack {

            // The same wash of their own colour your cigarette has, at half
            // strength. Without it a custom design comes down to a tip and a
            // filter, and the thing that makes it theirs never reads.
            design.background
                .mask(Ellipse())
                .frame(width: height * 0.22, height: height * 1.1)
                .blur(radius: height * 0.09)
                .opacity(0.4)

            VStack(spacing: 0) {

                Color.clear
                    .frame(width: width, height: spacerHeight)

                // The real ember, not the flat glow the courtyard draws.
                // Across the courtyard that simplification is invisible; here
                // it is standing at full height beside a cigarette that is
                // burning properly, and it read as an unlit tip painted
                // orange - which is exactly what it was.
                CigaretteAshView(design: design, height: glowHeight, width: width)
                    .frame(width: width, height: glowHeight)

                LinearGradient(gradient: Gradient(colors: design.bodyArray),
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: width, height: bodyHeight)

                ZStack {

                    LinearGradient(gradient: Gradient(colors: design.filterArray),
                                   startPoint: .leading, endPoint: .trailing)

                    CigaretteGlowDots(height: filterHeight, width: width,
                                      color: design.filterDots, animated: false)
                }
                .frame(width: width, height: filterHeight)
            }
            .frame(width: width, height: height)

            // Quieter than your own name, which sits on the other side of
            // your cigarette in white. Theirs is a label on somebody else's
            // cigarette, not a title.
            Text(companion.name)
                .font(.caption2)
                .fixedSize()
                .foregroundStyle(.gray)
                .frame(width: height, alignment: .trailing)
                .rotationEffect(.degrees(90), anchor: .center)
                .offset(x: (mirrored ? -1 : 1) * (width / 2 + 9), y: 0)
                .opacity(0.8)
        }
        // Near, but never competing with the cigarette in your own hand.
        .opacity(0.9)
    }
}

#Preview {
    
    var design = CigDesign()
    design.title = "Charcoal Gull"
    
    let outgoing = BreakWait.opening(uid: "preview", design: design)
    let companion = Companion(waiter: outgoing)
    
    return VStack(spacing: 40) {
        
        WaitForCompanyView(state: .idle, unlit: true, suppressed: false, wait: {}, clear: {})
        WaitForCompanyView(state: .waiting(outgoing), unlit: true, suppressed: false, wait: {}, clear: {})
        WaitForCompanyView(
            state: .together(companion, since: .now),
            unlit: false,
            suppressed: false,
            wait: {},
            clear: {}
        )
        WaitForCompanyView(state: .alone, unlit: true, suppressed: false, wait: {}, clear: {})
        
        WaitDetailView(wait: outgoing, join: {})
        
        CompanionCigaretteView(companion: companion, progress: 0.4, height: 180)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
}
