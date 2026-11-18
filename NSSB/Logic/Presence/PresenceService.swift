//
//  PresenceService.swift
//  NSSB
//

// The seam between the app and whatever is holding presence.
//
// Everything above this protocol is backend-agnostic, so the courtyard can be
// built and run before a Firebase project exists, and so the choice of
// backend never leaks into a view.

import Foundation

protocol PresenceService: AnyObject {
    
    /// Anonymous sign-in. No account, no email, no password, nothing to
    /// recover and nothing to lose. Returns the uid.
    func signIn() async throws -> String
    
    /// Publishes a live break. One document, deleted when it ends.
    func publish(_ presence: BreakPresence) async throws
    
    /// Deletes the break document.
    ///
    /// There is no TTL policy on this project (it needs the Blaze plan), so
    /// this is the only thing that removes a document. The repository also
    /// retries it on the next launch for a break the app was killed during.
    func withdraw(id: String) async throws
    
    /// Everyone else currently lit, capped. Reads are the cost driver here,
    /// so this is a bounded query with a listener attached only for the
    /// duration of a break - never a running count of the collection.
    func observeCourtyard(limit: Int, onChange: @escaping ([BreakPresence]) -> Void)
    
    func stopObservingCourtyard()
    
    /// How many breaks are burning anywhere right now, including your own.
    ///
    /// A count() aggregation, which Firestore bills as one read per thousand
    /// index entries - so this is one read, not one per person. The proposal
    /// assumed a scheduled Cloud Function writing a stats document would be
    /// needed to avoid counting the collection; it is not, and the aggregation
    /// is both cheaper and simpler.
    func liveCount() async throws -> Int
    
    /// Breaks that ended recently - the embers people left behind.
    ///
    /// One query, run once when a break starts. These are real breaks by real
    /// people; the only thing being stretched is which minute it is.
    func recentEchoes(limit: Int, within: TimeInterval) async throws -> [BreakPresence]
    
    /// Deletes a few documents that went stale more than `olderThan` ago.
    ///
    /// This project has no TTL policy, so nothing sweeps the collection on its
    /// own. Every client clears a handful whenever it lights up, which keeps
    /// the collection bounded without a scheduled function - and the rules
    /// only permit deleting documents that are certainly litter.
    func sweepStale(olderThan: TimeInterval, limit: Int) async throws -> Int
    
    // MARK: Asking for a light
    
    /// Publishes an open ask. Eight seconds, addressed to the whole
    /// courtyard rather than to a person - see BreakAsk for why that is the
    /// whole feature rather than a detail of it.
    func openAsk(_ ask: BreakAsk) async throws
    
    /// Watches your own ask for the one thing that can happen to it:
    /// somebody answering. A document listener, not a query, and attached for
    /// eight seconds.
    func observeOwnAsk(id: String, onChange: @escaping (BreakAsk) -> Void)
    
    func stopObservingOwnAsk()
    
    /// Everyone else's open asks. Attached only while your own cigarette is
    /// lit, because an unlit cigarette has nothing to give.
    func observeAsks(limit: Int, onChange: @escaping ([BreakAsk]) -> Void)
    
    func stopObservingAsks()
    
    /// Answers an ask.
    ///
    /// Throws when somebody else got there first: the rules permit exactly
    /// one `claimed: false -> true` transition, so the race is settled by the
    /// server and the loser finds out here rather than by being told by a
    /// client that it lost.
    func claimAsk(
        id: String,
        giverName: String,
        giverDesign: CigDesign,
        giverProgress: Double,
        giverCountry: String?,
        giverTzOffset: Int
    ) async throws

    /// Removes your own ask - answered, timed out, or cancelled. Same
    /// reasoning as `withdraw`: nothing else will.
    func withdrawAsk(id: String) async throws
    
    /// Takes the bins out in the asks collection.
    func sweepStaleAsks(olderThan: TimeInterval, limit: Int) async throws -> Int
    
    // MARK: Waiting for company
    
    /// Publishes an open wait: an unlit cigarette standing in the courtyard
    /// for thirty seconds. See BreakWait for why both sides of Synchrony are
    /// unlit, which is what removes the matching problem entirely.
    func openWait(_ wait: BreakWait) async throws
    
    /// Watches your own wait for the one thing that can happen to it:
    /// somebody joining. A document listener, attached for thirty seconds.
    func observeOwnWait(id: String, onChange: @escaping (BreakWait) -> Void)
    
    func stopObservingOwnWait()
    
    /// Everyone else who is waiting. Attached only while you are waiting
    /// too - a lit cigarette cannot start together with anybody, and this is
    /// also the only time the courtyard is visible to an unlit smoker.
    func observeWaits(limit: Int, onChange: @escaping ([BreakWait]) -> Void)
    
    func stopObservingWaits()
    
    /// Takes the free chair.
    ///
    /// Throws when somebody else sat down first: the rules permit exactly one
    /// `paired: false -> true` transition, so the race is settled by the
    /// server and the loser finds out here.
    ///
    /// `litAt` is the shared ignition instant, written by whoever joins and
    /// read by the waiter. Both cigarettes burn from it, which is the whole
    /// of "ending on the same second".
    func pairWith(
        id: String,
        partnerName: String,
        partnerDesign: CigDesign,
        partnerCountry: String?,
        partnerTzOffset: Int,
        litAt: Date
    ) async throws
    
    /// Removes your own wait - joined, timed out, or cancelled.
    func withdrawWait(id: String) async throws
    
    /// Takes the bins out in the waits collection.
    func sweepStaleWaits(olderThan: TimeInterval, limit: Int) async throws -> Int

}

enum PresenceError: LocalizedError {
    
    case notConfigured
    case notSignedIn
    case askAlreadyAnswered
    case waitAlreadyPaired
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No Firebase project is configured. See firebase/README.md."
        case .notSignedIn:
            return "Tried to publish a break before signing in."
        case .askAlreadyAnswered:
            return "Somebody else got there first."
        case .waitAlreadyPaired:
            return "Somebody else took the chair."
        }
    }
}

// MARK: - Development stand-in

/// Development scaffolding, not a product decision.
///
/// This exists so the courtyard can be built and looked at before there is a
/// backend. It is NOT the presence floor from the proposal - that is built
/// from echoes of real breaks and needs real data to echo. Nothing in here
/// should ever end up standing in for a person in a shipped build, which is
/// why it is only selected when no Firebase project is configured at all.
final class SimulatedPresenceService: PresenceService {
    
    private var published: [String: BreakPresence] = [:]
    private var timer: Timer?
    private var onChange: (([BreakPresence]) -> Void)?
    private var limit: Int = 20
    private var uid: String = ""
    
    func signIn() async throws -> String {
        self.uid = "simulated-" + UUID().uuidString.prefix(8)
        return self.uid
    }
    
    func publish(_ presence: BreakPresence) async throws {
        published[presence.id] = presence
        print("Presence - published \(presence.name), ends \(presence.endsAt)")
    }
    
    func withdraw(id: String) async throws {
        published[id] = nil
        print("Presence - withdrew \(id)")
    }
    
    func observeCourtyard(limit: Int, onChange: @escaping ([BreakPresence]) -> Void) {
        
        self.limit = limit
        self.onChange = onChange
        
        emit()
        
        // A real snapshot listener pushes; this polls itself so the burn
        // positions visibly advance while the UI is being built.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.emit()
        }
    }
    
    func stopObservingCourtyard() {
        timer?.invalidate()
        timer = nil
        onChange = nil
    }
    
    func liveCount() async throws -> Int {
        sample.filter { $0.isLive() }.count
    }
    
    func recentEchoes(limit: Int, within: TimeInterval) async throws -> [BreakPresence] {
        []
    }
    
    func sweepStale(olderThan: TimeInterval, limit: Int) async throws -> Int { 0 }
    
    // MARK: Asking for a light
    
    // Faithful plumbing, and nothing more. The state machine above can be
    // driven end to end against this - opened, answered, withdrawn - which is
    // what makes it testable without a network.
    //
    // Deliberately nobody ever answers by themselves. The invented breaks
    // further down exist so there is something on screen during development,
    // and manufacturing presence is already a stretch; manufacturing a gift
    // would be a lie about another person having done something kind. So an
    // ask left alone here times out, exactly as it does in an empty
    // courtyard.
    
    private var asks: [String: BreakAsk] = [:]
    
    /// Everything this stand-in is holding, answered asks included.
    ///
    /// The real service cannot be asked this question without a read - and
    /// "is anything left behind?" is exactly the question the live flow has
    /// to be checked against the server for, rather than asked of a client.
    var askIds: [String] { Array(asks.keys) }
    
    private var ownAskId: String?
    private var onOwnAskChange: ((BreakAsk) -> Void)?
    private var onAsksChange: (([BreakAsk]) -> Void)?
    
    func openAsk(_ ask: BreakAsk) async throws {
        asks[ask.id] = ask
        print("Presence - asked the courtyard for a light (\(ask.name))")
        emitAsks()
        emitOwnAsk()
    }
    
    func observeOwnAsk(id: String, onChange: @escaping (BreakAsk) -> Void) {
        ownAskId = id
        onOwnAskChange = onChange
        emitOwnAsk()
    }
    
    func stopObservingOwnAsk() {
        ownAskId = nil
        onOwnAskChange = nil
    }
    
    func observeAsks(limit: Int, onChange: @escaping ([BreakAsk]) -> Void) {
        onAsksChange = onChange
        emitAsks()
    }
    
    func stopObservingAsks() {
        onAsksChange = nil
    }
    
    func claimAsk(
        id: String,
        giverName: String,
        giverDesign: CigDesign,
        giverProgress: Double,
        giverCountry: String?,
        giverTzOffset: Int
    ) async throws {

        guard var ask = asks[id], ask.claimed == false else {
            throw PresenceError.askAlreadyAnswered
        }

        ask.claimed = true
        ask.giverName = giverName
        ask.giverDesign = giverDesign
        ask.giverProgress = giverProgress
        ask.giverCountry = giverCountry
        ask.giverTzOffset = giverTzOffset
        asks[id] = ask
        
        emitAsks()
        emitOwnAsk()
    }
    
    func withdrawAsk(id: String) async throws {
        asks[id] = nil
        emitAsks()
    }
    
    func sweepStaleAsks(olderThan: TimeInterval, limit: Int) async throws -> Int { 0 }
    
    private func emitOwnAsk() {
        guard let id = ownAskId, let ask = asks[id] else { return }
        onOwnAskChange?(ask)
    }
    
    private func emitAsks() {
        
        // Your own ask is never an offer - you cannot give yourself a light,
        // and the rules say so too. Filtered the same way the real service
        // does it, by recomputing the hash rather than by storing a uid.
        let open = asks.values.filter {
            $0.isOpen() && $0.askerHash != BreakOwner.hash(uid: uid, breakId: $0.id)
        }
        
        onAsksChange?(Array(open))
    }
    
    // MARK: Waiting for company
    
    // Same honesty as the asks above: nobody here ever joins a wait by
    // itself. An invented cigarette standing in the courtyard is atmosphere;
    // an invented cigarette that sits down next to you and smokes a whole
    // five minutes with you is a lie about company, which is the one thing
    // this feature exists to provide. So a wait left alone here times out,
    // exactly as it does in an empty courtyard.
    
    private var waits: [String: BreakWait] = [:]
    
    /// Everything this stand-in is holding, paired waits included.
    var waitIds: [String] { Array(waits.keys) }
    
    private var ownWaitId: String?
    private var onOwnWaitChange: ((BreakWait) -> Void)?
    private var onWaitsChange: (([BreakWait]) -> Void)?
    
    func openWait(_ wait: BreakWait) async throws {
        waits[wait.id] = wait
        print("Presence - waiting for company (\(wait.name))")
        emitWaits()
        emitOwnWait()
    }
    
    func observeOwnWait(id: String, onChange: @escaping (BreakWait) -> Void) {
        ownWaitId = id
        onOwnWaitChange = onChange
        emitOwnWait()
    }
    
    func stopObservingOwnWait() {
        ownWaitId = nil
        onOwnWaitChange = nil
    }
    
    func observeWaits(limit: Int, onChange: @escaping ([BreakWait]) -> Void) {
        onWaitsChange = onChange
        emitWaits()
    }
    
    func stopObservingWaits() {
        onWaitsChange = nil
    }
    
    func pairWith(
        id: String,
        partnerName: String,
        partnerDesign: CigDesign,
        partnerCountry: String?,
        partnerTzOffset: Int,
        litAt: Date
    ) async throws {
        
        guard var wait = waits[id], wait.paired == false else {
            throw PresenceError.waitAlreadyPaired
        }
        
        wait.paired = true
        wait.partnerName = partnerName
        wait.partnerDesign = partnerDesign
        wait.partnerCountry = partnerCountry
        wait.partnerTzOffset = partnerTzOffset
        wait.litAt = litAt
        waits[id] = wait
        
        emitWaits()
        emitOwnWait()
    }
    
    func withdrawWait(id: String) async throws {
        waits[id] = nil
        emitWaits()
    }
    
    func sweepStaleWaits(olderThan: TimeInterval, limit: Int) async throws -> Int { 0 }
    
    private func emitOwnWait() {
        guard let id = ownWaitId, let wait = waits[id] else { return }
        onOwnWaitChange?(wait)
    }
    
    private func emitWaits() {
        
        // Your own wait is never company - you cannot keep yourself company,
        // and the rules say so too. Filtered the way the real service does
        // it, by recomputing the hash rather than by storing a uid.
        let open = waits.values.filter {
            $0.isOpen() && $0.waiterHash != BreakOwner.hash(uid: uid, breakId: $0.id)
        }
        
        onWaitsChange?(Array(open))
    }
    
    private func emit() {
        
        let now = Date.now
        let others = sample
            .filter { $0.isLive(at: now) }
            .prefix(limit)
        
        onChange?(Array(others))
    }
    
    /// A handful of invented breaks on a rolling schedule, purely so there is
    /// something on screen during development.
    private lazy var sample: [BreakPresence] = {
        
        let now = Date.now
        
        return (0..<4).map { index in
            
            let startedAt = now.addingTimeInterval(-Double(index) * 70 - 20)
            var design = getRandom()
            design.title = randomCigaretteName()
            
            let id = "simulated-\(index)"
            
            return BreakPresence(
                id: id,
                ownerHash: BreakOwner.hash(uid: "simulated-other-\(index)", breakId: id),
                startedAt: startedAt,
                endsAt: startedAt.addingTimeInterval(Date.breakLength),
                name: design.title,
                country: ["PT", "JP", "BR", "IE"][index],
                tzOffset: [3600, 32400, -10800, 0][index],
                design: design
            )
        }
    }()
}
