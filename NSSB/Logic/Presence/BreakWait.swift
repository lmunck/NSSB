//
//  BreakWait.swift
//  NSSB
//

// Layer 3: smoking together.
//
// The proposal called this "two people both near the start, burning in
// parallel, ending on the same second" and called it the only layer that
// needs matched remaining time. It does not, and that was the whole problem
// with it.
//
// Matching only exists if you join somebody who is already burning. If both
// people are unlit and start together, there is nothing to match: the break
// is five minutes for both of them because it begins at one shared instant.
// So Synchrony is between two *unlit* strangers, and "ending on the same
// second" is literally true rather than approximately true.
//
// Everything else follows from layer 2's constraints. Nobody is addressed, so
// nobody is refused - joining a waiter is taking the free chair at a table,
// not asking permission, and the first tap wins. Nothing in the presence
// floor can be waited with, because an echo is not waiting for anybody. And
// if nobody comes within thirty seconds you light your own, exactly as an
// unanswered ask does after eight.

import Foundation

struct BreakWait: Codable, Equatable, Identifiable, CourtyardStranger {
    
    let id: String
    
    /// sha256(uid + waitId). Same reasoning as BreakPresence.ownerHash: the
    /// rules can verify it, nobody else can link two waits with it.
    let waiterHash: String
    
    let createdAt: Date
    
    /// createdAt + BreakWait.window.
    let expiresAt: Date
    
    /// The waiter, so their unlit cigarette can be drawn standing there.
    let name: String
    let country: String?
    let tzOffset: Int
    let design: CigDesign
    
    /// False until somebody joins. The rules permit exactly one transition to
    /// true, so if two people reach for the same free chair the server picks
    /// one rather than the client.
    var paired: Bool
    
    /// Who sat down. Nil until paired.
    var partnerName: String?
    var partnerDesign: CigDesign?
    var partnerCountry: String?
    var partnerTzOffset: Int?
    
    /// The shared instant. Written by whoever joins, read by the waiter, and
    /// used as `breakStarted` by both - which is the entire mechanism behind
    /// two cigarettes ending on the same second.
    var litAt: Date?
}

extension BreakWait {
    
    /// Thirty seconds. Longer than an ask, because asking is a question
    /// somebody answers in a moment and waiting is standing about - but still
    /// short enough that it ends by itself while you are still looking at it.
    ///
    /// A var only so the state machine's thirty seconds can be tested without
    /// a test spending thirty seconds, which is why `BreakAsk.window` and
    /// `Date.breakLength` are vars too. Nothing in the app assigns to it.
    static var window: TimeInterval = 30
    
    static func opening(
        at createdAt: Date = .now,
        id: String = UUID().uuidString,
        uid: String,
        design: CigDesign,
        shareCountry: Bool = true
    ) -> BreakWait {
        
        BreakWait(
            id: id,
            waiterHash: BreakOwner.hash(uid: uid, breakId: id),
            createdAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(window),
            name: design.title,
            country: shareCountry ? Locale.current.region?.identifier : nil,
            tzOffset: TimeZone.current.secondsFromGMT(for: createdAt),
            design: design,
            paired: false,
            partnerName: nil,
            partnerDesign: nil,
            partnerCountry: nil,
            partnerTzOffset: nil,
            litAt: nil
        )
    }
    
    func isOpen(at now: Date = .now) -> Bool {
        paired == false && now < expiresAt
    }
    
    /// 0 at the moment of stepping outside, 1 when the wait runs out. Drives
    /// the fade on the unlit cigarette standing in the courtyard.
    func progress(at now: Date = .now) -> Double {
        let total = expiresAt.timeIntervalSince(createdAt)
        guard total > 0 else { return 1 }
        return min(max(now.timeIntervalSince(createdAt) / total, 0), 1)
    }
}

// MARK: - Who you are standing with

/// The other half of a shared break.
///
/// No progress field, unlike `AskGiver`. There is nothing to carry: you lit
/// at the same instant, so their burn position is your burn position, and the
/// view draws theirs from your own clock without asking the network.
struct Companion: Equatable, CourtyardStranger {
    
    let name: String
    let design: CigDesign
    let country: String?
    let tzOffset: Int
    
    /// Seen from the waiter's side: the person who joined them.
    init?(partnerOf wait: BreakWait) {
        guard let name = wait.partnerName, name.isEmpty == false else { return nil }
        self.name = name
        self.design = wait.partnerDesign ?? CigDesign()
        self.country = wait.partnerCountry
        self.tzOffset = wait.partnerTzOffset ?? 0
    }
    
    /// Seen from the joiner's side: the person who was already standing there.
    init(waiter wait: BreakWait) {
        self.name = wait.name
        self.design = wait.design
        self.country = wait.country
        self.tzOffset = wait.tzOffset
    }
}

/// The whole life of a shared break, the same on both sides.
///
/// Like `AskState` it only moves forward, and for the same reason: there is
/// no state for being turned down, because nobody can turn anybody down.
/// Silence is the only no, and after thirty seconds of it you light your own.
enum CompanyState: Equatable {
    
    case idle
    
    /// Your unlit cigarette is standing in the courtyard, waiting.
    case waiting(BreakWait)
    
    /// Lit together, at `since`, and burning in parallel until they both go
    /// out. This is the one state in the app that lasts a whole cigarette.
    case together(Companion, since: Date)
    
    /// Thirty seconds, nobody came, lighting your own. Transient - it is a
    /// line of text that clears itself.
    case alone
    
    var isWaiting: Bool {
        if case .waiting = self { return true }
        return false
    }
    
    /// The wait itself, while it is still out there.
    var openWait: BreakWait? {
        if case .waiting(let wait) = self { return wait }
        return nil
    }
    
    /// Who you are smoking with, if anybody.
    var companion: Companion? {
        if case .together(let companion, _) = self { return companion }
        return nil
    }
    
    /// The shared ignition instant, which both cigarettes burn from.
    var litAt: Date? {
        if case .together(_, let since) = self { return since }
        return nil
    }
}
