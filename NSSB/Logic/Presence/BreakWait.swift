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
/// One reach-out, seen from the outside.
///
/// The app runs two mechanisms underneath - an ask that a burning stranger
/// can answer, a wait that an unlit one can join - but a person tapped once
/// and wants one thing. This is that one thing, so the row under the
/// cigarette never has to explain which of the two is currently in play.
enum Outreach: Equatable {

    case idle

    /// Standing out there, both halves live. The date is when the longer of
    /// the two gives up, so the bar drains once rather than twice.
    case reaching(until: Date)

    /// Somebody is giving you a light. The tips are touching.
    case lit(AskGiver)

    /// Somebody is out here with you.
    case together([Companion])

    /// They lit you and went straight back in - there was not enough of
    /// their cigarette left to stay for.
    case answered(AskGiver)

    /// Nobody came. You are lighting your own, which is what happens most
    /// times and has never been the bad outcome.
    case alone
}

struct Companion: Equatable, CourtyardStranger {
    
    let name: String
    let design: CigDesign
    let country: String?
    let tzOffset: Int

    /// When *their* cigarette was lit, which is not always when yours was.
    ///
    /// Two people who light together share this instant exactly, and their
    /// cigarettes go out on the same second. Somebody who came over and lit
    /// you was already burning, so theirs started earlier and will be gone
    /// before yours is - which is what happens outside, and is the honest
    /// thing to draw.
    let startedAt: Date

    /// Which side of you they stand on.
    ///
    /// Taken from where they would have been in the courtyard, so somebody
    /// who was over to your left comes to stand on your left. That is random
    /// and reads as natural because it is. Overwritten only when the side is
    /// already taken - two people never stand in the same place.
    var side: CompanionSide
    
    /// True when a handoff put the two of you tip to tip: either they
    /// stopped to light you, or you stopped to light them. Both end with
    /// them at your lit end, which is where they walk out from.
    ///
    /// False for two people who lit at the same instant, who were never
    /// anywhere near each other's cigarettes.
    func metAtYourTip(whenYouLitAt since: Date) -> Bool {
        abs(startedAt.timeIntervalSince(since)) > 1
    }
    
    /// Seen from the waiter's side: the person who joined them.
    init?(partnerOf wait: BreakWait) {
        guard let name = wait.partnerName, name.isEmpty == false,
              let litAt = wait.litAt
        else { return nil }
        self.name = name
        self.design = wait.partnerDesign ?? CigDesign()
        self.country = wait.partnerCountry
        self.tzOffset = wait.partnerTzOffset ?? 0
        self.startedAt = litAt
        self.side = Companion.naturalSide(for: name)
    }

    /// Seen from the joiner's side: the person who was already standing there.
    init(waiter wait: BreakWait, litAt: Date) {
        self.name = wait.name
        self.design = wait.design
        self.country = wait.country
        self.tzOffset = wait.tzOffset
        self.startedAt = litAt
        self.side = Companion.naturalSide(for: wait.name)
    }

    /// Somebody who was already out here and stopped to light you.
    ///
    /// Their burn position is the one thing the ask carries about them, so it
    /// is where their cigarette comes from: wind it back from the moment the
    /// tips touched and you have the instant they lit their own.
    init(giver: AskGiver, metAt: Date) {
        self.name = giver.name
        self.design = giver.design
        self.country = giver.country
        self.tzOffset = giver.tzOffset
        self.startedAt = metAt.addingTimeInterval(-giver.progress * Date.breakLength)
        self.side = Companion.naturalSide(for: giver.name)
    }

    /// Somebody you stopped to light, who lit at the moment the tips
    /// touched. The mirror of `giver`: this one is behind you rather than
    /// ahead, so you will go back inside and leave them out here.
    init(lit ask: BreakAsk, at litAt: Date) {
        self.name = ask.name
        self.design = ask.design
        self.country = ask.country
        self.tzOffset = ask.tzOffset
        self.startedAt = litAt
        self.side = Companion.naturalSide(for: ask.name)
    }

    /// Where they would have been standing out in the courtyard.
    static func naturalSide(for name: String) -> CompanionSide {
        Courtyard.position(for: name).x < 0.5 ? .left : .right
    }

    /// How far down their cigarette is, 0 to 1. Theirs, not yours.
    func progress(at now: Date = .now) -> Double {
        min(max(now.timeIntervalSince(startedAt) / Date.breakLength, 0), 1)
    }

    /// True once their cigarette has gone out and they have gone back in.
    func hasGone(at now: Date = .now) -> Bool { progress(at: now) >= 1 }
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
    /// Who is standing with you. At most two, because there are two sides
    /// of you to stand on - and because somebody's neighbour has their own
    /// other neighbour, so the courtyard is a chain of overlapping pairs
    /// rather than a crowd. You can get your own lit and then turn and light
    /// somebody else, which makes you a link rather than a recipient.
    case together([Companion], since: Date)
    
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
    
    /// Who you are smoking with. Empty unless somebody is out here.
    var companions: [Companion] {
        if case .together(let companions, _) = self { return companions }
        return []
    }
    
    /// Both sides of you are taken, so nobody else can stand with you - the
    /// light is still yours to give, the place beside you is not.
    var isFull: Bool { companions.count >= 2 }
    
    /// The shared ignition instant, which both cigarettes burn from.
    var litAt: Date? {
        if case .together(_, let since) = self { return since }
        return nil
    }

    /// Adds somebody to your side, if there is a side left.
    ///
    /// Their own side if it is free, the other one if it is not, and nothing
    /// at all if both are taken. Sides are kept rather than recomputed so
    /// nobody shuffles across when the person on the other side finishes.
    func standing(with newcomer: Companion, since: Date) -> CompanyState {
        
        var all = companions
        guard all.count < 2 else { return self }
        guard all.contains(where: { $0.name == newcomer.name }) == false else { return self }
        
        var placed = newcomer
        if all.contains(where: { $0.side == placed.side }) {
            placed.side = placed.side.opposite
        }
        all.append(placed)
        
        // The earlier instant wins the same tiebreak it always has: two
        // people who lit together must agree on when that was.
        if case .together(_, let already) = self {
            return .together(all, since: min(already, since))
        }
        return .together(all, since: since)
    }
    
    /// Whoever is left once somebody's cigarette is finished.
    func without(_ name: String) -> CompanyState {
        guard case .together(let all, let since) = self else { return self }
        let left = all.filter { $0.name != name }
        return left.isEmpty ? .idle : .together(left, since: since)
    }
}


/// Which side of you somebody is standing on. There are two, which is why
/// two is the most people who can stand with you.
enum CompanionSide: Equatable {

    case left, right

    var opposite: CompanionSide { self == .left ? .right : .left }
}
