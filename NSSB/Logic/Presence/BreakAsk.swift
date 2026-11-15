//
//  BreakAsk.swift
//  NSSB
//

// "Got a light?"
//
// Addressed to the whole courtyard, never to a person. That is not politeness
// for its own sake - it is what makes the feature work at all. Tapping one
// stranger creates declining, and a declined ask is a wound at both ends; it
// also means a cigarette in the presence floor would have to be able to
// answer, and manufacturing presence is one thing while manufacturing a gift
// is quite another.
//
// So the ask goes out, anyone lit can answer, the first one wins, and after
// eight seconds you light your own - which is what happens most times in real
// life anyway.

import Foundation

struct BreakAsk: Codable, Equatable, Identifiable {
    
    let id: String
    
    /// sha256(uid + askId). Same reasoning as BreakPresence.ownerHash: the
    /// rules can verify it, nobody else can link two asks with it.
    let askerHash: String
    
    let createdAt: Date
    
    /// createdAt + BreakAsk.window.
    let expiresAt: Date
    
    /// The asker, so their unlit cigarette can be drawn in the courtyard.
    let name: String
    let country: String?
    let tzOffset: Int
    let design: CigDesign
    
    /// False until somebody offers. The rules permit exactly one transition
    /// to true, so the race is settled by the server rather than the client.
    var claimed: Bool
    
    /// Who answered. Nil until claimed.
    var giverName: String?
    var giverDesign: CigDesign?
    
    /// How far through their own cigarette the giver was when they offered.
    ///
    /// Kept so the handoff can show the truth: being lit by someone almost
    /// finished looks different from being lit by someone who just started,
    /// and it should.
    var giverProgress: Double?
}

extension BreakAsk {
    
    /// Eight seconds. Long enough to be answered, short enough that an
    /// unanswered ask is not left hanging in anyone's courtyard.
    static let window: TimeInterval = 8
    
    static func opening(
        at createdAt: Date = .now,
        id: String = UUID().uuidString,
        uid: String,
        design: CigDesign,
        shareCountry: Bool = true
    ) -> BreakAsk {
        
        BreakAsk(
            id: id,
            askerHash: BreakOwner.hash(uid: uid, breakId: id),
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(window),
            name: design.title,
            country: shareCountry ? Locale.current.region?.identifier : nil,
            tzOffset: TimeZone.current.secondsFromGMT(for: createdAt),
            design: design,
            claimed: false,
            giverName: nil,
            giverDesign: nil,
            giverProgress: nil
        )
    }
    
    func isOpen(at now: Date = .now) -> Bool {
        claimed == false && now < expiresAt
    }
    
    /// 0 at the moment of asking, 1 when it times out - drives the pulse on
    /// the dark cigarette standing in everyone's courtyard.
    func progress(at now: Date = .now) -> Double {
        let total = expiresAt.timeIntervalSince(createdAt)
        guard total > 0 else { return 1 }
        return min(max(now.timeIntervalSince(createdAt) / total, 0), 1)
    }
}
