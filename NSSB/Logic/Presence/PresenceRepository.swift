//
//  PresenceRepository.swift
//  NSSB
//

// Owns the one presence document this device publishes, and the listener on
// everyone else's. Nothing above this knows which backend is underneath.
//
// Layer 0 of the plan: a break is published and withdrawn. Nothing is drawn
// yet - `courtyard` is populated and ready for the count to be built on top.

import Foundation
import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@MainActor
final class PresenceRepository: ObservableObject {
    
    /// Everyone else currently lit. Empty until a break is running, because
    /// the listener is only attached for the length of a cigarette.
    @Published private(set) var courtyard: [BreakPresence] = []
    
    /// Nil until the first successful sign-in.
    @Published private(set) var uid: String?
    
    private let service: PresenceService
    
    /// The break this device is currently publishing, if any.
    private var publishedBreak: BreakPresence?
    
    /// Survives being killed mid-break. Without it, a relaunch publishes a
    /// second document for the same cigarette and the user appears twice in
    /// their own courtyard until the first one times out.
    @AppStorage("presence.liveBreakId") private var storedBreakId: String = ""
    @AppStorage("presence.liveBreakStart") private var storedBreakStart: Double = 0
    
    /// Cap from the proposal: enough to fill a courtyard, few enough that a
    /// five-minute break is a handful of reads rather than a bill.
    private let courtyardLimit = 20
    
    /// Whether to put a flag on this break. Opt-out lives here so the rest
    /// of the code never has to think about it.
    var shareCountry: Bool = true
    
    init(service: PresenceService? = nil) {
        self.service = service ?? PresenceRepository.defaultService()
    }
    
    /// Firestore when the package and a GoogleService-Info.plist are both
    /// present, otherwise the development stand-in so the app still runs.
    ///
    /// Setup has two halves that are easy to do one of and not the other, so
    /// this says which one is missing rather than failing over silently.
    private static func defaultService() -> PresenceService {
        
        let hasPlist = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        
        #if canImport(FirebaseFirestore)
        if hasPlist {
            let project = FirebaseApp.app()?.options.projectID ?? "unknown"
            print("Presence - using Firestore, project \(project)")
            return FirestorePresenceService()
        }
        print("Presence - the Firebase SDK is linked, but GoogleService-Info.plist is not in the NSSB target. Falling back to the simulated service. See firebase/README.md step 1.")
        #else
        if hasPlist {
            print("Presence - GoogleService-Info.plist is present, but the Firebase SDK is not linked. Falling back to the simulated service. See firebase/README.md step 2.")
        } else {
            print("Presence - no Firebase project configured yet, using the simulated service.")
        }
        #endif
        
        return SimulatedPresenceService()
    }
    
    // MARK: Lifecycle
    
    /// Called once, at launch.
    func start() async {
        do {
            self.uid = try await service.signIn()
            print("Presence - signed in anonymously")
        } catch {
            // Firebase's own message for most auth failures is "An internal
            // error has occurred, print and inspect the error details" - the
            // actual reason is buried in the userInfo, so print it.
            let ns = error as NSError
            print("Presence - sign-in failed: \(ns.domain) code \(ns.code) - \(ns.localizedDescription)")
            for (key, value) in ns.userInfo {
                print("Presence -   \(key): \(value)")
            }
        }
    }
    
    /// A break began, or an already-running one was found at launch.
    ///
    /// `startedAt` is the real start, not "now", so a break that was running
    /// when the app was killed comes back at its true position in the burn
    /// rather than restarting.
    func breakStarted(at startedAt: Date, design: CigDesign) async {
        
        guard startedAt.breakIsActive else { return }
        
        // Already publishing this break - a relaunch or a redundant change.
        if let published = publishedBreak, published.startedAt == startedAt { return }
        
        guard let uid = self.uid else {
            print("Presence - not signed in yet, break not published")
            return
        }
        
        // Same cigarette as before the app died - reuse its document.
        let isSameBreak = storedBreakId.isEmpty == false
            && Int(storedBreakStart) == Int(startedAt.timeIntervalSince1970)
        
        let presence = BreakPresence.starting(
            at: startedAt,
            id: isSameBreak ? storedBreakId : UUID().uuidString,
            uid: uid,
            design: design,
            shareCountry: shareCountry
        )
        
        do {
            try await service.publish(presence)
            self.publishedBreak = presence
            self.storedBreakId = presence.id
            self.storedBreakStart = startedAt.timeIntervalSince1970
            
            if isSameBreak {
                print("Presence - resumed \(presence.name) at its real burn position")
            }
            
            service.observeCourtyard(limit: courtyardLimit) { [weak self] others in
                Task { @MainActor in
                    self?.courtyard = others
                    
                    if others.isEmpty {
                        print("Presence - courtyard: nobody else out there")
                    } else {
                        let who = others.map {
                            "\($0.name) (\($0.country ?? "--"), \($0.localTimeString()), \(Int($0.progress() * 100))% burnt)"
                        }
                        print("Presence - courtyard: \(others.count) other(s) - \(who.joined(separator: ", "))")
                    }
                }
            }
            
        } catch {
            print("Presence - publish failed: \(error.localizedDescription)")
        }
    }
    
    /// The cigarette went out, or the break was cancelled. Everything ends
    /// when the cigarette does: the document goes, the listener detaches, and
    /// the courtyard is dropped rather than kept around to look at.
    func breakEnded() async {
        
        service.stopObservingCourtyard()
        self.courtyard = []
        
        // Either the break being published right now, or one left behind by a
        // previous launch that was killed mid-cigarette and never got to
        // withdraw it. The stored id is the only trace of that one, so it has
        // to be used before it is cleared - otherwise the document sits in the
        // courtyard until a TTL policy sweeps it, and there may not be one.
        let orphan = storedBreakId.isEmpty ? nil : storedBreakId
        guard let id = publishedBreak?.id ?? orphan else { return }
        
        let wasOrphan = publishedBreak == nil
        self.publishedBreak = nil
        
        do {
            try await service.withdraw(id: id)
            
            // Only now is it safe to forget. A failed withdraw keeps the id so
            // the next launch can try again.
            self.storedBreakId = ""
            self.storedBreakStart = 0
            
            if wasOrphan {
                print("Presence - cleaned up a break left behind by an earlier launch")
            }
            
        } catch {
            print("Presence - withdraw failed, will retry next launch: \(error.localizedDescription)")
        }
    }
}
