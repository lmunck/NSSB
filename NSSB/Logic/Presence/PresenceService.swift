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
}

enum PresenceError: LocalizedError {
    
    case notConfigured
    case notSignedIn
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No Firebase project is configured. See firebase/README.md."
        case .notSignedIn:
            return "Tried to publish a break before signing in."
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
