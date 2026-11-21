//
//  FirestorePresenceService.swift
//  NSSB
//

// The real backend.
//
// Everything here is behind `canImport`, so this file compiles to nothing
// until the Firebase SPM package is added to the target - the project keeps
// building in the meantime, and lights up by itself once the package is
// there. See firebase/README.md for the three steps that need a Google
// account and therefore cannot be done from here.

import Foundation

#if canImport(FirebaseFirestore)

import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

final class FirestorePresenceService: PresenceService {
    
    // Lazy, so this can never be touched before FirebaseApp.configure() has
    // run. SwiftUI evaluates a @StateObject's initial value lazily, so the
    // ordering already works out - this just removes the question.
    private lazy var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var ownAskListener: ListenerRegistration?
    private var asksListener: ListenerRegistration?
    private var ownWaitListener: ListenerRegistration?
    private var waitsListener: ListenerRegistration?
    private var uid: String?
    
    private let collection = "presence"
    private let asksCollection = "asks"
    private let waitsCollection = "waits"
    
    // MARK: Auth
    
    /// Anonymous only, and it should stay that way. Nothing in a presence
    /// document identifies a person beyond a country code and a cigarette
    /// they rolled themselves.
    func signIn() async throws -> String {
        
        if let existing = Auth.auth().currentUser?.uid {
            self.uid = existing
            return existing
        }
        
        let result = try await Auth.auth().signInAnonymously()
        self.uid = result.user.uid
        
        return result.user.uid
    }
    
    // MARK: Writing
    
    func publish(_ presence: BreakPresence) async throws {
        
        guard uid != nil else { throw PresenceError.notSignedIn }
        
        // Encoded first, then awaited, on purpose.
        //
        // setData(from:) only throws if encoding fails. The write itself goes
        // to the local cache and is queued for the server, so a rules
        // rejection never reaches the caller - the app carries on believing
        // it published, the listener attaches, and the first snapshot even
        // contains the document, served from that same local cache. The
        // server quietly has nothing. Awaiting the untyped setData surfaces
        // the rejection where it belongs.
        let data = try Firestore.Encoder().encode(presence)
        
        try await db.collection(collection)
            .document(presence.id)
            .setData(data)
    }
    
    func withdraw(id: String) async throws {
        try await db.collection(collection).document(id).delete()
    }
    
    // MARK: Reading
    
    /// Bounded on purpose. Reads are the only real cost in this design, so
    /// the query is capped, the listener is attached for the duration of one
    /// break and detached the moment the cigarette goes out, and the global
    /// count is never derived by reading the collection.
    func observeCourtyard(limit: Int, onChange: @escaping ([BreakPresence]) -> Void) {
        
        stopObservingCourtyard()
        
        let ownUid = self.uid
        
        listener = db.collection(collection)
            .whereField("endsAt", isGreaterThan: Date.now)
            .order(by: "endsAt")
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                
                if let error = error {
                    Log.presence.error("Presence - listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Log.presence.debug("Presence - query returned \(documents.count) live break(s)")
                
                let others: [BreakPresence] = documents.compactMap { document in
                    
                    guard let presence = try? document.data(as: BreakPresence.self) else {
                        Log.presence.debug("Presence - could not decode \(document.documentID)")
                        return nil
                    }
                    
                    // Your own cigarette is drawn in front, not in the
                    // crowd. Recomputed rather than compared directly,
                    // because the document no longer carries a uid.
                    if let ownUid = ownUid,
                       presence.ownerHash == BreakOwner.hash(uid: ownUid, breakId: presence.id) {
                        return nil
                    }
                    
                    return presence
                }
                
                onChange(others)
            }
    }
    
    func stopObservingCourtyard() {
        listener?.remove()
        listener = nil
    }
    
    /// Breaks whose cigarettes went out within the given window.
    ///
    /// Two inequalities on the same field, which Firestore allows, and a
    /// single read of at most `limit` documents. Run once at the start of a
    /// break rather than listened to: an ember is not news.
    func recentEchoes(limit: Int, within: TimeInterval) async throws -> [BreakPresence] {
        
        let now = Date.now
        
        let snapshot = try await db.collection(collection)
            .whereField("endsAt", isLessThan: now)
            .whereField("endsAt", isGreaterThan: now.addingTimeInterval(-within))
            .order(by: "endsAt", descending: true)
            .limit(to: limit)
            .getDocuments(source: .server)
        
        let ownUid = self.uid
        
        return snapshot.documents.compactMap { document in
            guard let presence = try? document.data(as: BreakPresence.self) else { return nil }
            if let ownUid = ownUid,
               presence.ownerHash == BreakOwner.hash(uid: ownUid, breakId: presence.id) {
                return nil
            }
            return presence
        }
    }
    
    /// Takes the bins out: deletes a few documents nobody can see any more.
    ///
    /// Bounded on purpose - a handful per break, not the whole backlog. With
    /// every client doing this whenever it lights up, the collection stays
    /// small without a TTL policy or a scheduled function.
    func sweepStale(olderThan: TimeInterval, limit: Int) async throws -> Int {
        
        let cutoff = Date.now.addingTimeInterval(-olderThan)
        
        let snapshot = try await db.collection(collection)
            .whereField("endsAt", isLessThan: cutoff)
            .order(by: "endsAt")
            .limit(to: limit)
            .getDocuments(source: .server)
        
        for document in snapshot.documents {
            try? await document.reference.delete()
        }
        
        return snapshot.documents.count
    }
    
    /// One read, regardless of how many people are out there.
    ///
    /// Firestore bills an aggregation per thousand index entries, so this
    /// stays a single read until the app has a thousand simultaneous breaks.
    /// Deliberately not a snapshot listener: the number does not need to be
    /// live to the second, and a listener on an unbounded query is the one
    /// thing in this design that could actually run up a bill.
    func liveCount() async throws -> Int {
        
        let snapshot = try await db.collection(collection)
            .whereField("endsAt", isGreaterThan: Date.now)
            .count
            .getAggregation(source: .server)
        
        return snapshot.count.intValue
    }
    
    // MARK: - Asking for a light
    
    /// Same encode-then-await as `publish`, for the same reason: a rules
    /// rejection has to reach the caller. An ask that was refused by the
    /// server but believed by the client is worse here than anywhere else -
    /// the asker would stand waiting eight seconds for an answer to a
    /// question nobody was ever asked.
    func openAsk(_ ask: BreakAsk) async throws {
        
        guard uid != nil else { throw PresenceError.notSignedIn }
        
        let data = try Firestore.Encoder().encode(ask)
        
        try await db.collection(asksCollection)
            .document(ask.id)
            .setData(data)
    }
    
    /// A document listener on your own ask, for the eight seconds it lives.
    ///
    /// Snapshots can be served from the local cache, and the first one here
    /// always is - it is our own write coming back. That is harmless, because
    /// the only transition this is watching for is `claimed` becoming true,
    /// which this device never writes and the rules forbid it from writing.
    /// So a claim can only ever have come from the server, and from somebody
    /// else.
    func observeOwnAsk(id: String, onChange: @escaping (BreakAsk) -> Void) {
        
        stopObservingOwnAsk()
        
        ownAskListener = db.collection(asksCollection)
            .document(id)
            .addSnapshotListener { snapshot, error in
                
                if let error = error {
                    Log.presence.error("Presence - own ask listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists,
                      let ask = try? snapshot.data(as: BreakAsk.self) else { return }
                
                onChange(ask)
            }
    }
    
    func stopObservingOwnAsk() {
        ownAskListener?.remove()
        ownAskListener = nil
    }
    
    /// Asks that are still open, excluding your own.
    ///
    /// Ordered and bounded on `expiresAt` alone, and `claimed` is filtered
    /// here rather than in the query. Adding an equality on `claimed` would
    /// turn this into a composite index for no benefit: the window is eight
    /// seconds wide, so the slice this reads is a handful of documents even
    /// when the courtyard is busy, and an answered ask that arrives is simply
    /// dropped on this side.
    func observeAsks(limit: Int, onChange: @escaping ([BreakAsk]) -> Void) {
        
        stopObservingAsks()
        
        let ownUid = self.uid
        
        asksListener = db.collection(asksCollection)
            .whereField("expiresAt", isGreaterThan: Date.now)
            .order(by: "expiresAt")
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                
                if let error = error {
                    Log.presence.error("Presence - asks listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let open: [BreakAsk] = documents.compactMap { document in
                    
                    guard let ask = try? document.data(as: BreakAsk.self) else { return nil }
                    guard ask.isOpen() else { return nil }
                    
                    // Your own ask, which you may not answer - the rules say
                    // so too, but it should never be drawn as an offer.
                    if let ownUid = ownUid,
                       ask.askerHash == BreakOwner.hash(uid: ownUid, breakId: ask.id) {
                        return nil
                    }
                    
                    return ask
                }
                
                if open.isEmpty == false {
                    Log.presence.debug("Presence - \(open.count) open ask(s) in the courtyard")
                }
                
                onChange(open)
            }
    }
    
    func stopObservingAsks() {
        asksListener?.remove()
        asksListener = nil
    }
    
    /// The one write that can lose.
    ///
    /// `updateData` rather than `setData`, because the rule compares the
    /// incoming document against the one already there: exactly one
    /// `claimed: false -> true` transition is permitted, so if two people
    /// reach for their lighter at the same moment the server picks one and
    /// this throws for the other. That is the whole race, settled where it
    /// should be - and awaited, so the loser actually finds out.
    func claimAsk(
        id: String,
        giverName: String,
        giverDesign: CigDesign,
        giverProgress: Double,
        giverCountry: String?,
        giverTzOffset: Int
    ) async throws {

        guard uid != nil else { throw PresenceError.notSignedIn }

        let design = try Firestore.Encoder().encode(giverDesign)

        try await db.collection(asksCollection)
            .document(id)
            .updateData([
                "claimed": true,
                "giverName": giverName,
                "giverDesign": design,
                "giverProgress": giverProgress,
                // Same as pairing a wait: a dictionary with a nil value in it
                // is a dictionary with the key missing, so say absent out loud.
                "giverCountry": giverCountry ?? NSNull(),
                "giverTzOffset": giverTzOffset
            ])
    }
    
    func withdrawAsk(id: String) async throws {
        try await db.collection(asksCollection).document(id).delete()
    }
    
    /// An ask is eight seconds long, so anything the rules will let anyone
    /// delete here has been litter for five minutes. Same bounded handful as
    /// the presence sweep.
    func sweepStaleAsks(olderThan: TimeInterval, limit: Int) async throws -> Int {
        
        let cutoff = Date.now.addingTimeInterval(-olderThan)
        
        let snapshot = try await db.collection(asksCollection)
            .whereField("expiresAt", isLessThan: cutoff)
            .order(by: "expiresAt")
            .limit(to: limit)
            .getDocuments(source: .server)
        
        for document in snapshot.documents {
            try? await document.reference.delete()
        }
        
        return snapshot.documents.count
    }
    
    // MARK: - Waiting for company
    
    /// Same encode-then-await as every other write here, for the same
    /// reason: `setData(from:)` reports encoding failures and nothing else,
    /// so a rules rejection would leave somebody standing in a courtyard
    /// nobody can see them in, waiting out thirty seconds for company that
    /// was never asked for.
    func openWait(_ wait: BreakWait) async throws {
        
        guard uid != nil else { throw PresenceError.notSignedIn }
        
        let data = try Firestore.Encoder().encode(wait)
        
        try await db.collection(waitsCollection)
            .document(wait.id)
            .setData(data)
    }
    
    /// A document listener on your own wait, for the thirty seconds it lives.
    ///
    /// The first snapshot is always our own write coming back from the local
    /// cache, which is harmless for the same reason it is harmless on an ask:
    /// the only transition being watched for is `paired` becoming true, which
    /// this device never writes and the rules forbid it from writing.
    func observeOwnWait(id: String, onChange: @escaping (BreakWait) -> Void) {
        
        stopObservingOwnWait()
        
        ownWaitListener = db.collection(waitsCollection)
            .document(id)
            .addSnapshotListener { snapshot, error in
                
                if let error = error {
                    Log.presence.error("Presence - own wait listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists,
                      let wait = try? snapshot.data(as: BreakWait.self) else { return }
                
                onChange(wait)
            }
    }
    
    func stopObservingOwnWait() {
        ownWaitListener?.remove()
        ownWaitListener = nil
    }
    
    /// Everyone else who is standing out there waiting, excluding you.
    ///
    /// Bounded and ordered on `expiresAt` alone, with `paired` filtered on
    /// this side - the same trade as the asks listener, and for the same
    /// reason: a thirty-second window is a handful of documents, and a
    /// composite index would buy nothing.
    func observeWaits(limit: Int, onChange: @escaping ([BreakWait]) -> Void) {
        
        stopObservingWaits()
        
        let ownUid = self.uid
        
        waitsListener = db.collection(waitsCollection)
            .whereField("expiresAt", isGreaterThan: Date.now)
            .order(by: "expiresAt")
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                
                if let error = error {
                    Log.presence.error("Presence - waits listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let open: [BreakWait] = documents.compactMap { document in
                    
                    guard let wait = try? document.data(as: BreakWait.self) else { return nil }
                    guard wait.isOpen() else { return nil }
                    
                    // Your own wait, which you may not join - the rules say
                    // so too, but it should never be drawn as company.
                    if let ownUid = ownUid,
                       wait.waiterHash == BreakOwner.hash(uid: ownUid, breakId: wait.id) {
                        return nil
                    }
                    
                    return wait
                }
                
                if open.isEmpty == false {
                    Log.presence.debug("Presence - \(open.count) other(s) waiting for company")
                }
                
                onChange(open)
            }
    }
    
    func stopObservingWaits() {
        waitsListener?.remove()
        waitsListener = nil
    }
    
    /// The other write that can lose.
    ///
    /// `updateData` rather than `setData`, so the rule can compare against
    /// the document already there: exactly one `paired: false -> true`
    /// transition is permitted, so if two people reach for the same free
    /// chair the server picks one and this throws for the other.
    func pairWith(
        id: String,
        partnerName: String,
        partnerDesign: CigDesign,
        partnerCountry: String?,
        partnerTzOffset: Int,
        litAt: Date
    ) async throws {
        
        guard uid != nil else { throw PresenceError.notSignedIn }
        
        let design = try Firestore.Encoder().encode(partnerDesign)
        
        // NSNull rather than nil: a country is genuinely absent for anyone
        // who opted out of the flag, and a dictionary with a nil value in it
        // is a dictionary with the key missing, which the waiter would decode
        // as "not sent yet" rather than "not shared".
        try await db.collection(waitsCollection)
            .document(id)
            .updateData([
                "paired": true,
                "partnerName": partnerName,
                "partnerDesign": design,
                "partnerCountry": partnerCountry ?? NSNull(),
                "partnerTzOffset": partnerTzOffset,
                "litAt": Timestamp(date: litAt)
            ])
    }
    
    func withdrawWait(id: String) async throws {
        try await db.collection(waitsCollection).document(id).delete()
    }
    
    /// A wait is thirty seconds long, so anything the rules will let anyone
    /// delete here has been litter for five minutes.
    func sweepStaleWaits(olderThan: TimeInterval, limit: Int) async throws -> Int {
        
        let cutoff = Date.now.addingTimeInterval(-olderThan)
        
        let snapshot = try await db.collection(waitsCollection)
            .whereField("expiresAt", isLessThan: cutoff)
            .order(by: "expiresAt")
            .limit(to: limit)
            .getDocuments(source: .server)
        
        for document in snapshot.documents {
            try? await document.reference.delete()
        }
        
        return snapshot.documents.count
    }
}

#endif
