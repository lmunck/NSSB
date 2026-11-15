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
        giverProgress: Double
    ) async throws
    
    /// Removes your own ask - answered, timed out, or cancelled. Same
    /// reasoning as `withdraw`: nothing else will.
    func withdrawAsk(id: String) async throws
    
    /// Takes the bins out in the asks collection.
    func sweepStaleAsks(olderThan: TimeInterval, limit: Int) async throws -> Int

}

enum PresenceError: LocalizedError {
    
    case notConfigured
    case notSignedIn
    case askAlreadyAnswered
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No Firebase project is configured. See firebase/README.md."
        case .notSignedIn:
            return "Tried to publish a break before signing in."
        case .askAlreadyAnswered:
            return "Somebody else got there first."
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
        giverProgress: Double
    ) async throws {
        
        guard var ask = asks[id], ask.claimed == false else {
            throw PresenceError.askAlreadyAnswered
        }
        
        ask.claimed = true
        ask.giverName = giverName
        ask.giverDesign = giverDesign
        ask.giverProgress = giverProgress
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
        let open = asks.values.filter { $0.isOpen() }
        onAsksChange?(Array(open))
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
