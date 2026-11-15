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
    private var uid: String?
    
    private let collection = "presence"
    
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
                    print("Presence - listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                print("Presence - query returned \(documents.count) live break(s)")
                
                let others: [BreakPresence] = documents.compactMap { document in
                    
                    guard let presence = try? document.data(as: BreakPresence.self) else {
                        print("Presence - could not decode \(document.documentID)")
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
}

#endif
