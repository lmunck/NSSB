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
    
    /// Breaks that ended in the last hour, shown as dying embers so the
    /// courtyard is never completely dark. Real people, real cigarettes -
    /// just not this minute. Disclosed in the info panel.
    @Published private(set) var echoes: [BreakPresence] = []
    
    /// Nil until the first successful sign-in.
    @Published private(set) var uid: String?
    
    /// Everyone lit anywhere right now, including you. Nil until it has been
    /// asked for once - the difference between "nobody" and "we do not know
    /// yet" matters, because the courtyard should never claim to be empty
    /// when it simply has not looked.
    @Published private(set) var liveCount: Int?
    
    /// Your own ask for a light, from going out to being over.
    @Published private(set) var ask: AskState = .idle
    
    /// Other people's open asks: the dark cigarettes standing in your
    /// courtyard, waiting. Only ever populated while your own cigarette is
    /// lit, because an unlit cigarette has nothing to give.
    @Published private(set) var offers: [BreakAsk] = []
    
    /// The ask you are answering right now, while the two tips touch. Nil
    /// the rest of the time.
    @Published private(set) var giving: BreakAsk?
    
    /// Waiting for somebody to smoke with, and then smoking with them. The
    /// one piece of state in this app that lasts a whole cigarette.
    @Published private(set) var company: CompanyState = .idle
    
    /// Other people standing out here unlit, waiting for company. Only ever
    /// populated while you are waiting too: a lit cigarette cannot start
    /// together with anybody, so there would be nothing to do with them.
    @Published private(set) var waiting: [BreakWait] = []
    
    private let service: PresenceService
    
    /// The break this device is currently publishing, if any.
    private var publishedBreak: BreakPresence?
    
    /// Fires when the eight seconds are up. Cancelled the moment somebody
    /// answers, so a light that arrives at 7.9 seconds is not thrown away.
    /// True while one tap is out as both an ask and a wait.
    ///
    /// Asking and waiting are two mechanisms for one intention, and while
    /// they are running together the ask is only the first of two chances.
    /// So an unanswered ask must not announce a result or light anything -
    /// the wait is still out there, and it owns the ending.
    private var reaching = false

    private var askTimeout: Task<Void, Never>?
    
    /// The handoff is an animation, and an animation can be interrupted - the
    /// app backgrounded, the view torn down. The gift was still given, so
    /// this moves the state on by itself if nothing told it the ceremony
    /// finished. Comfortably longer than the animation, which is about two
    /// and a half seconds.
    private var handoffNet: Task<Void, Never>?
    private var offerNet: Task<Void, Never>?
    
    /// Fires when the thirty seconds are up. Cancelled the moment somebody
    /// joins, so company that arrives at 29.9 seconds is not thrown away.
    private var waitTimeout: Task<Void, Never>?

    /// One per companion, firing when that person's own cigarette runs
    /// out. Keyed by the document they came from, because the two of them
    /// finish at different times:
    /// somebody who lit you goes in before you do, somebody you lit stays
    /// out here after you have gone.
    private var companionTimers: [String: Task<Void, Never>] = [:]
    
    /// Survives being killed mid-break. Without it, a relaunch publishes a
    /// second document for the same cigarette and the user appears twice in
    /// their own courtyard until the first one times out.
    @AppStorage("presence.liveBreakId") private var storedBreakId: String = ""
    @AppStorage("presence.liveBreakStart") private var storedBreakStart: Double = 0
    
    /// Cap from the proposal: enough to fill a courtyard, few enough that a
    /// five-minute break is a handful of reads rather than a bill.
    private let courtyardLimit = 20
    
    /// How many embers to pull in, and how far back to look for them.
    private let echoLimit = 4
    private let echoWindow: TimeInterval = 60 * 60
    
    /// Open asks to show at once. An ask lives eight seconds, so this is a
    /// far smaller slice than the courtyard even when the place is busy.
    private let askLimit = 6
    
    /// How stale an ask has to be before anyone may clear it. Matches the
    /// delete rule, which allows it five minutes after it expired.
    private let askLitter: TimeInterval = 60 * 6
    
    /// Open waits to show at once. A wait lives thirty seconds, so even a
    /// busy courtyard has only a handful standing about.
    private let waitLimit = 6
    
    /// How stale a wait has to be before anyone may clear it. Matches its
    /// delete rule: five minutes after a thirty-second wait expired.
    private let waitLitter: TimeInterval = 60 * 6
    
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
            Log.presence.debug("Presence - using Firestore, project \(project)")
            return FirestorePresenceService()
        }
        Log.presence.debug("Presence - the Firebase SDK is linked, but GoogleService-Info.plist is not in the NSSB target. Falling back to the simulated service. See firebase/README.md step 1.")
        #else
        if hasPlist {
            Log.presence.debug("Presence - GoogleService-Info.plist is present, but the Firebase SDK is not linked. Falling back to the simulated service. See firebase/README.md step 2.")
        } else {
            Log.presence.debug("Presence - no Firebase project configured yet, using the simulated service.")
        }
        #endif
        
        return SimulatedPresenceService()
    }
    
    // MARK: The count
    
    /// Cheap enough to call on launch and at either end of a break, which is
    /// as often as the number meaningfully changes for this user.
    func refreshCount() async {
        do {
            self.liveCount = try await service.liveCount()
        } catch {
            Log.presence.error("Presence - count failed: \(error.localizedDescription)")
        }
    }
    
    /// Everyone except you.
    ///
    /// While a break is running the courtyard listener is attached, so the
    /// live list is both cheaper and more current than the aggregation - and
    /// using it keeps the screen honest. Reading "quiet out here right now"
    /// with a stranger's cigarette visibly burning behind it is worse than
    /// either message alone.
    ///
    /// Outside a break there is no listener, so the periodic count stands in.
    /// It excludes your own document, because "1 other" when that one is
    /// yourself reads as a lie.
    /// An attached listener that has not spoken yet is not an empty
    /// courtyard. Without this the count flips to "quiet out here right now"
    /// for the second between lighting up and the first snapshot arriving -
    /// with a stranger's cigarette about to appear behind it.
    private var courtyardSeen = false

    var othersCount: Int? {

        if publishedBreak != nil {
            guard courtyardSeen else { return nil }
            
            // Everybody out here, not everybody lit. Somebody standing
            // right there asking is present - they just have not got their
            // cigarette going yet - and counting only embers put "quiet out
            // here right now" on screen with a person visibly in it.
            return courtyard.count + offers.count
        }

        guard let liveCount = liveCount else { return nil }
        return liveCount
    }
    
    /// Pulled once per break. Not a listener - an ember is not news.
    func loadEchoes() async {
        do {
            self.echoes = try await service.recentEchoes(limit: echoLimit, within: echoWindow)
            if echoes.isEmpty == false {
                Log.presence.debug("Presence - \(echoes.count) ember(s) still warm")
            }
        } catch {
            Log.presence.error("Presence - echoes failed: \(error.localizedDescription)")
        }
        
        // Take a few bins out while we are here. Nothing else will.
        do {
            let swept = try await service.sweepStale(olderThan: echoWindow + 60, limit: 5)
            if swept > 0 { Log.presence.debug("Presence - swept \(swept) stale document(s)") }
        } catch {
            Log.presence.error("Presence - sweep failed: \(error.localizedDescription)")
        }
        
        // And the asks, which the asker normally deletes itself. What is left
        // here is an ask whose owner was killed in the eight seconds between
        // asking and finding out, so there is very little of it - but with no
        // TTL policy, very little that is never cleared still adds up.
        do {
            let swept = try await service.sweepStaleAsks(olderThan: askLitter, limit: 5)
            if swept > 0 { Log.presence.debug("Presence - swept \(swept) stale ask(s)") }
        } catch {
            Log.presence.error("Presence - ask sweep failed: \(error.localizedDescription)")
        }
        
        // And the waits, for the same reason: a waiter who was killed in the
        // thirty seconds before anybody joined leaves a document nothing
        // else will ever clear.
        do {
            let swept = try await service.sweepStaleWaits(olderThan: waitLitter, limit: 5)
            if swept > 0 { Log.presence.debug("Presence - swept \(swept) stale wait(s)") }
        } catch {
            Log.presence.error("Presence - wait sweep failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: Lifecycle
    
    /// Called once, at launch.
    func start() async {
        do {
            self.uid = try await service.signIn()
            Log.presence.debug("Presence - signed in anonymously")
            await refreshCount()
        } catch {
            // Firebase's own message for most auth failures is "An internal
            // error has occurred, print and inspect the error details" - the
            // actual reason is buried in the userInfo, so print it.
            let ns = error as NSError
            Log.presence.error("Presence - sign-in failed: \(ns.domain) code \(ns.code) - \(ns.localizedDescription)")
            for (key, value) in ns.userInfo {
                Log.presence.debug("Presence -   \(key): \(value)")
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
        
        // You lit your own while an ask was still out. Take it down: a dark
        // cigarette standing in somebody's courtyard asking for a light you
        // no longer need is a small lie, and it would waste their gift.
        //
        // A break that starts because somebody answered is already past
        // .asking by this point, so this cannot cancel the ask that caused it.
        if ask.isAsking { await cancelAsk() }
        
        // Same for a wait: you lit your own while still standing out there
        // waiting for company. A break that starts *because* somebody joined
        // is already past .waiting by this point, so this cannot cancel the
        // pairing that caused it.
        if company.isWaiting { await cancelWait() }
        
        guard let uid = self.uid else {
            Log.presence.debug("Presence - not signed in yet, break not published")
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
                Log.presence.debug("Presence - resumed \(presence.name) at its real burn position")
            }
            
            await refreshCount()
            await loadEchoes()
            
            service.observeCourtyard(limit: courtyardLimit) { [weak self] others in
                Task { @MainActor in
                    self?.courtyard = others
                    self?.courtyardSeen = true
                    
                    if others.isEmpty {
                        Log.presence.debug("Presence - courtyard: nobody else out there")
                    } else {
                        let who = others.map {
                            "\($0.name) (\($0.country ?? "--"), \($0.daylight().rawValue), \(Int($0.progress() * 100))% burnt)"
                        }
                        Log.presence.debug("Presence - courtyard: \(others.count) other(s) - \(who.joined(separator: ", "))")
                    }
                }
            }
            
            // Your cigarette is lit, so you are now somebody who can answer.
            service.observeAsks(limit: askLimit) { [weak self] asks in
                Task { @MainActor in
                    self?.offers = asks
                }
            }
            
        } catch {
            Log.presence.error("Presence - publish failed: \(error.localizedDescription)")
        }
    }
    
    /// The cigarette went out, or the break was cancelled. Everything ends
    /// when the cigarette does: the document goes, the listener detaches, and
    /// the courtyard is dropped rather than kept around to look at.
    func breakEnded() async {
        
        service.stopObservingCourtyard()
        service.stopObservingAsks()
        service.stopObservingWaits()
        self.courtyard = []
        self.courtyardSeen = false
        self.echoes = []
        self.offers = []
        self.giving = nil
        self.waiting = []
        
        // The next unlit cigarette starts over, and can ask again.
        //
        // From any state, not only a finished one. An ask caught mid-gesture
        // by the cigarette going out used to stay as it was - and both the
        // row and `reachOut` read that as something still in flight, so the
        // screen went on saying somebody was giving you a light and there
        // was no way to ask anybody for one. Whatever the ask was doing, the
        // cigarette it belonged to is gone.
        askTimeout?.cancel()
        askTimeout = nil
        handoffNet?.cancel()
        handoffNet = nil
        offerNet?.cancel()
        offerNet = nil
        reaching = false
        if case .idle = ask {} else { self.ask = .idle }
        
        // Company lasts exactly as long as the cigarettes do. Whoever you
        // stood with, you are not standing with them any more, and nothing
        // about it is kept - which is the first principle of the whole layer.
        companionTimers.values.forEach { $0.cancel() }
        companionTimers = [:]
        if case .idle = company {} else { self.company = .idle }
        
        // A break that ran its course is left in place, to linger as an ember
        // for anyone who lights up in the next hour. A break that was
        // cancelled is deleted, because it did not happen - standing in
        // someone's courtyard on the strength of a cigarette you stubbed out
        // after four seconds would be a lie.
        //
        // Nobody else can delete it either way until it is an hour stale, at
        // which point the sweep rule lets any client clear it.
        if let published = publishedBreak, Date.now >= published.endsAt.addingTimeInterval(-2) {
            self.publishedBreak = nil
            self.storedBreakId = ""
            self.storedBreakStart = 0
            return
        }
        
        // Either the break being cancelled now, or one left behind by a
        // previous launch that was killed mid-cigarette. The stored id is the
        // only trace of that one, so it has to be used before it is cleared.
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
                Log.presence.debug("Presence - cleaned up a break left behind by an earlier launch")
            }
            
        } catch {
            Log.presence.error("Presence - withdraw failed, will retry next launch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Got a light?
    
    /// The two machines read as the single gesture they are.
    ///
    /// Company outranks everything: once somebody is out here with you, how
    /// they got here stopped mattering. Below that the ask leads, because
    /// being lit is a thing happening to you right now, and the draining bar
    /// comes last because it is only the absence of the others.
    var outreach: Outreach {

        if case .together(let companions, _) = company { return .together(companions) }
        if case .lit(let giver) = ask { return .lit(giver) }
        if case .done(let giver) = ask, let giver = giver { return .answered(giver) }

        // The wait first: it is the longer of the two, so it owns the bar.
        if let out = company.openWait { return .reaching(until: out.expiresAt) }
        if let out = ask.openAsk { return .reaching(until: out.expiresAt) }

        if case .alone = company { return .alone }
        if case .done(let giver) = ask, giver == nil { return .alone }

        return .idle
    }

    /// One tap, both ways of not smoking alone.
    ///
    /// A lit stranger can hand you a light; an unlit one can light at the
    /// same instant as you. Those are two mechanisms, and giving each its own
    /// button made the plumbing into the interface - nobody standing outside
    /// has two intentions, they have one, and it is that they would rather
    /// not smoke alone. So both go out on one tap, whichever is answered
    /// first wins, and the other is taken down.
    func reachOut(design: CigDesign) async {

        guard case .idle = ask, case .idle = company else { return }

        reaching = true

        async let asked: Void = askForALight(design: design)
        async let waited: Void = waitForCompany(design: design)
        _ = await (asked, waited)

        // Neither could be opened - no backend, or both writes refused. Land
        // where the silence would have landed anyway rather than leaving the
        // row saying nothing and the cigarette unlit.
        guard reaching else { return }
        if ask.openAsk == nil, company.openWait == nil {
            reaching = false
            self.ask = .idle
            self.company = .alone
        }
    }

    /// Where an ask ends when nobody answers it.
    ///
    /// On its own that is a result worth saying out loud. Inside a reach-out
    /// it is nothing at all: the longer half of the same gesture is still
    /// running, and announcing here would light the cigarette while somebody
    /// could still walk out.
    private func askEndedUnanswered() {
        
        // Still reaching, or somebody is already out here with you. Either
        // way "nobody answered" is not true, and saying it would strand the
        // row on a result that never clears, because the line it belongs to
        // is not the one on screen.
        guard reaching == false, company.companions.isEmpty else {
            self.ask = .idle
            return
        }
        
        self.ask = .done(givenBy: nil)
    }

    /// Asks the whole courtyard.
    ///
    /// Not a person. Tapping one stranger would create declining, and a
    /// declined ask is a wound at both ends - see BreakAsk. So this goes out
    /// to everyone who is lit, anyone may answer, and the first one wins.
    func askForALight(design: CigDesign) async {
        
        guard case .idle = ask else { return }
        
        guard let uid = self.uid else {
            Log.presence.debug("Presence - not signed in yet, cannot ask")
            // Without a backend there is nobody to ask, so fall through to
            // the same place eight seconds of silence would have led.
            askEndedUnanswered()
            return
        }
        
        // A nameless cigarette cannot stand in anyone's courtyard, and the
        // rules reject an empty name outright. The caller rolls one; this is
        // the belt to that pair of braces, because a silent rejection here
        // would look exactly like nobody answering.
        var design = design
        if design.title.isEmpty { design.title = randomCigaretteName() }
        
        let outgoing = BreakAsk.opening(
            uid: uid,
            design: design,
            shareCountry: shareCountry
        )
        
        do {
            try await service.openAsk(outgoing)
        } catch {
            Log.presence.error("Presence - ask failed: \(error.localizedDescription)")
            askEndedUnanswered()
            return
        }
        
        self.ask = .asking(outgoing)
        Log.presence.debug("Presence - asked the courtyard for a light")
        
        service.observeOwnAsk(id: outgoing.id) { [weak self] incoming in
            Task { @MainActor in
                self?.ownAskChanged(incoming)
            }
        }
        
        // Eight seconds, measured from the document rather than from now, so
        // a slow round trip eats into the wait instead of extending it.
        askTimeout = Task { [weak self] in
            let wait = outgoing.expiresAt.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
            guard Task.isCancelled == false else { return }
            await self?.askRanOut()
        }
    }
    
    /// The only thing that can happen to your ask: somebody answered it.
    private func ownAskChanged(_ incoming: BreakAsk) {
        
        guard ask.isAsking, incoming.claimed, let giver = AskGiver(incoming) else { return }
        
        askTimeout?.cancel()
        askTimeout = nil
        service.stopObservingOwnAsk()
        
        Log.presence.debug("Presence - \(giver.name) gave you a light")
        self.ask = .lit(by: giver)
        armHandoffNet(giver: giver)

        // The gesture is answered. Take the other half down before the
        // handoff plays, or somebody could come out and sit in a chair you
        // are already walking away from.
        reaching = false
        if company.isWaiting { Task { await cancelWait() } }
        
        // Answered means finished. Nothing is left behind, and nobody else
        // can offer a light to an ask that has already been granted.
        Task { await removeOwnAsk(id: incoming.id) }
    }
    
    /// Eight seconds of silence.
    private func askRanOut() async {
        
        guard let outgoing = ask.openAsk else { return }
        
        service.stopObservingOwnAsk()
        askTimeout = nil
        
        if reaching {
            Log.presence.debug("Presence - nobody lit was out there, still waiting")
        } else {
            Log.presence.debug("Presence - nobody answered, lighting your own")
        }
        askEndedUnanswered()

        await removeOwnAsk(id: outgoing.id)
    }
    
    /// You took the question back - by lighting your own, or by leaving.
    func cancelAsk() async {
        
        guard let outgoing = ask.openAsk else { return }
        
        askTimeout?.cancel()
        askTimeout = nil
        service.stopObservingOwnAsk()
        self.ask = .idle

        // Taking the question back by hand ends the whole gesture.
        reaching = false

        await removeOwnAsk(id: outgoing.id)
    }
    
    /// The handoff has played out. From here the cigarette is just lit.
    func handoffFinished() {
        handoffNet?.cancel()
        handoffNet = nil
        guard case .lit(let giver) = ask else { return }
        self.ask = .done(givenBy: giver)
        stayWith(giver)
    }

    /// The person who lit you does not simply vanish.
    ///
    /// They were out here before you and they stay for what is left of their
    /// own cigarette, which is less than yours because theirs was already
    /// burning. So this is company with an end written into it: they finish,
    /// they go back inside, and you smoke the last of yours alone. Two
    /// strangers lighting together remains the only case where both go out
    /// on the same second, and it stays rare, which is what makes it worth
    /// anything.
    private func stayWith(_ giver: AskGiver) {

        guard company.isFull == false else { return }

        let met = Date.now
        let companion = Companion(giver: giver, metAt: met)

        // They were on their last mouthful. Lighting you was the whole of
        // the encounter, and drawing them beside you for two seconds would
        // be worse than not drawing them at all.
        guard companion.hasGone(at: met) == false else { return }

        Log.presence.debug("Presence - \(companion.name) is staying for the rest of theirs")
        stand(with: companion, since: met)
    }
    
    /// Their cigarette is finished. They go back inside, the line under
    /// yours stops naming them, and whoever is left stays.
    private func companionLeft(_ id: String) {
        companionTimers[id] = nil
        guard let gone = company.companions.first(where: { $0.id == id }) else { return }
        Log.presence.debug("Presence - \(gone.name) has gone back in")
        self.company = company.without(id)
    }
    
    private func armHandoffNet(giver: AskGiver) {
        handoffNet?.cancel()
        handoffNet = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard Task.isCancelled == false else { return }
            self?.forceHandoffFinished(giver: giver)
        }
    }
    
    private func forceHandoffFinished(giver: AskGiver) {
        guard case .lit = ask else { return }
        Log.presence.debug("Presence - the handoff never finished, moving on without it")
        self.ask = .done(givenBy: giver)
        stayWith(giver)
    }
    
    /// Clears the line of text that says what happened, once it has been
    /// read. Only from a finished state - this can never cut an ask short.
    func clearAsk() {
        guard case .done = ask else { return }
        self.ask = .idle
    }
    
    private func removeOwnAsk(id: String) async {
        do {
            try await service.withdrawAsk(id: id)
        } catch {
            // The sweep will get it. The rules let anyone clear an ask five
            // minutes after it expired, precisely for this.
            Log.presence.debug("Presence - could not remove the ask, leaving it to the sweep: \(error.localizedDescription)")
        }
    }
    
    // MARK: Answering somebody
    
    /// Gives a stranger a light.
    ///
    /// Everything about the gift comes from your own live break rather than
    /// from the caller, which is also what makes it impossible to give a
    /// light you do not have: no lit cigarette, nothing to offer.
    ///
    /// Can lose. The rules permit exactly one claim, so if two people reach
    /// for their lighter at the same moment the server picks one - and the
    /// other simply finds the ask gone, which is what would happen in a real
    /// courtyard too.
    func offerLight(to wanted: BreakAsk) async {
        
        guard giving == nil else { return }
        
        guard let mine = publishedBreak, mine.isLive() else {
            Log.presence.debug("Presence - nothing lit to give a light with")
            return
        }
        
        guard wanted.isOpen() else { return }
        
        do {
            try await service.claimAsk(
                id: wanted.id,
                giverName: mine.name,
                giverDesign: mine.design,
                giverProgress: mine.progress(),
                giverCountry: mine.country,
                giverTzOffset: mine.tzOffset
            )
            
            Log.presence.debug("Presence - gave \(wanted.name) a light")
            self.giving = wanted
            
            // Same net as the asking side: an interrupted animation must not
            // leave you unable to give anybody else a light.
            offerNet?.cancel()
            offerNet = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard Task.isCancelled == false else { return }
                self?.offerFinished()
            }
            
        } catch {
            // Somebody was quicker, or the ask expired between the tap and
            // the write. Either way it is no longer there to answer.
            Log.presence.debug("Presence - too late to give \(wanted.name) a light: \(error.localizedDescription)")
            self.offers.removeAll { $0.id == wanted.id }
        }
    }
    
    /// Their cigarette caught and the handoff is over.
    ///
    /// And then they stayed. This used to drop them straight back into the
    /// courtyard as one more distant cigarette, which made the app's answer
    /// to "are we smoking together" depend on which of us had asked. Now it
    /// does not: whoever lights whom, the two of you stand together
    /// afterwards.
    ///
    /// The asymmetry that is real stays. They lit at the moment the tips
    /// touched and you were already burning, so you finish first - you go
    /// back inside and leave them out here with most of theirs ahead of
    /// them. Which is the same rule as every other arrival: whoever has
    /// been burning longest goes in first.
    func offerFinished() {

        offerNet?.cancel()
        offerNet = nil

        guard let lit = giving else { return }
        self.giving = nil

        // Both sides of you already taken. The light was still theirs to
        // have - capping the company is reasonable, capping that is not.
        guard company.isFull == false else { return }

        let since = publishedBreak?.startedAt ?? .now
        stand(with: Companion(lit: lit, at: .now), since: since)
    }
    
    // MARK: - Smoking together
    
    /// Steps outside unlit and waits for somebody to start with.
    ///
    /// Both sides of this are unlit, which is what removes the matching
    /// problem the proposal thought this layer had: there is no remaining
    /// time to match, because the break has not begun. It begins when
    /// somebody joins, at one instant, for both of you.
    ///
    /// Waiting is also the only time an unlit smoker can see the courtyard.
    /// That is deliberate rather than incidental - a waiter who is invisible
    /// to everyone except people already waiting could never be found.
    func waitForCompany(design: CigDesign) async {
        
        guard case .idle = company else { return }
        
        guard let uid = self.uid else {
            Log.presence.debug("Presence - not signed in yet, cannot wait")
            // Nobody to wait for, so land where thirty seconds of silence
            // would have landed anyway.
            self.company = .alone
            return
        }
        
        // Same braces as the ask: the rules reject an empty name, and a
        // silent rejection would look exactly like nobody coming.
        var design = design
        if design.title.isEmpty { design.title = randomCigaretteName() }
        
        let outgoing = BreakWait.opening(
            uid: uid,
            design: design,
            shareCountry: shareCountry
        )
        
        do {
            try await service.openWait(outgoing)
        } catch {
            Log.presence.error("Presence - wait failed: \(error.localizedDescription)")
            self.company = .alone
            return
        }
        
        self.company = .waiting(outgoing)
        Log.presence.debug("Presence - waiting for company")
        
        service.observeOwnWait(id: outgoing.id) { [weak self] incoming in
            Task { @MainActor in
                self?.ownWaitChanged(incoming)
            }
        }
        
        // Everyone else out here doing the same thing. Either of you can take
        // the other's chair; whoever taps first gets it.
        service.observeWaits(limit: waitLimit) { [weak self] others in
            Task { @MainActor in
                self?.waiting = others
            }
        }
        
        // Thirty seconds, measured from the document rather than from now,
        // so a slow round trip eats into the wait instead of extending it.
        waitTimeout = Task { [weak self] in
            let left = outgoing.expiresAt.timeIntervalSinceNow
            if left > 0 {
                try? await Task.sleep(nanoseconds: UInt64(left * 1_000_000_000))
            }
            guard Task.isCancelled == false else { return }
            await self?.waitRanOut()
        }
    }
    
    /// Somebody sat down. The only thing that can happen to your wait.
    private func ownWaitChanged(_ incoming: BreakWait) {
        
        guard incoming.paired,
              let companion = Companion(partnerOf: incoming),
              let litAt = incoming.litAt
        else { return }
        
        Log.presence.debug("Presence - \(companion.name) is smoking with you")
        enterTogether(companion, since: litAt)
        
        // Paired means finished waiting. The document is ours, so clearing it
        // is ours to do - and it has to go, or a second person could try to
        // sit in a chair that is no longer free.
        Task { await removeOwnWait(id: incoming.id) }
    }
    
    /// Takes the free chair next to somebody who is already standing there.
    ///
    /// Can lose, exactly as offering a light can: the rules permit one
    /// pairing, so if two people sit down at the same moment the server picks
    /// one and the other finds the chair taken - which is what would happen
    /// in a real courtyard too.
    func waitWith(_ other: BreakWait, design: CigDesign) async {
        
        // Already smoking with somebody, so there is nothing to join.
        if case .together = company { return }
        
        guard other.isOpen() else { return }
        
        var design = design
        if design.title.isEmpty { design.title = randomCigaretteName() }
        
        // The shared instant. Written here, read by them, used as the start
        // of the break by both - so both cigarettes burn from the same second
        // and go out on the same second.
        let litAt = Date.now
        
        do {
            try await service.pairWith(
                id: other.id,
                partnerName: design.title,
                partnerDesign: design,
                partnerCountry: shareCountry ? Locale.current.region?.identifier : nil,
                partnerTzOffset: TimeZone.current.secondsFromGMT(for: litAt),
                litAt: litAt
            )
        } catch {
            Log.presence.debug("Presence - too late to stand with \(other.name): \(error.localizedDescription)")
            self.waiting.removeAll { $0.id == other.id }
            return
        }
        
        Log.presence.debug("Presence - standing with \(other.name)")
        
        // Read before the state moves on, not after: entering `.together` is
        // what ends the waiting, so by then `company.openWait` is nil and
        // your own chair would be left standing in the courtyard for
        // somebody to give their five minutes to.
        let mine = company.openWait
        
        enterTogether(Companion(waiter: other, litAt: litAt), since: litAt)
        
        // Your own wait, if you had one out, is over: you found company.
        if let mine = mine { await removeOwnWait(id: mine.id) }
    }
    
    /// Both sides land here, from opposite ends.
    ///
    /// The tiebreak is for the one race the rules cannot settle: two waiters
    /// taking each other's chair in the same instant, each succeeding on the
    /// other's document. Both are then standing with the person they meant to
    /// stand with, so there is nothing to undo - but they would be holding
    /// two ignition instants a fraction of a second apart. Both sides can see
    /// both values, so both sides keep the earlier one and stay in step.
    private func enterTogether(_ companion: Companion, since litAt: Date) {

        waitTimeout?.cancel()
        waitTimeout = nil
        service.stopObservingOwnWait()
        service.stopObservingWaits()
        self.waiting = []

        // Somebody came out, so the other half of the gesture is over. An
        // ask still standing in strangers' courtyards would be asking for a
        // light you no longer need.
        reaching = false
        if ask.isAsking { Task { await cancelAsk() } }
        
        stand(with: companion, since: litAt)
    }
    
    /// Somebody takes their place beside you, if there is a place left.
    ///
    /// Three things lead here and they are one arrival: a stranger answered
    /// your ask, a stranger took your chair, or you stopped and lit a
    /// stranger. Each is now out here with you, each on their own clock.
    private func stand(with companion: Companion, since: Date) {
        
        let before = company.companions.count
        self.company = company.standing(with: companion, since: since)
        
        guard company.companions.count > before else {
            Log.presence.debug("Presence - no room beside you for \(companion.name)")
            return
        }
        
        armDeparture(of: companion)
    }
    
    /// And then they go, each on their own cigarette, which is the only
    /// clock any of this runs on.
    private func armDeparture(of companion: Companion) {
        
        companionTimers[companion.id]?.cancel()
        companionTimers[companion.id] = Task { [weak self] in
            let left = Date.breakLength * (1 - companion.progress())
            if left > 0 {
                try? await Task.sleep(nanoseconds: UInt64(left * 1_000_000_000))
            }
            guard Task.isCancelled == false else { return }
            self?.companionLeft(companion.id)
        }
    }
    
    /// Thirty seconds of nobody.
    private func waitRanOut() async {
        
        guard let outgoing = company.openWait else { return }
        
        service.stopObservingOwnWait()
        service.stopObservingWaits()
        waitTimeout = nil
        self.waiting = []
        
        Log.presence.debug("Presence - nobody came out, lighting your own")
        reaching = false
        self.company = .alone
        
        await removeOwnWait(id: outgoing.id)
    }
    
    /// You went back inside - or lit your own rather than keep waiting.
    func cancelWait() async {
        
        guard let outgoing = company.openWait else { return }
        
        waitTimeout?.cancel()
        waitTimeout = nil
        service.stopObservingOwnWait()
        service.stopObservingWaits()
        self.waiting = []
        self.company = .idle

        // Going back inside ends the whole gesture, both halves of it.
        reaching = false

        await removeOwnWait(id: outgoing.id)
    }
    
    /// Clears the line that says nobody came, once it has been read. Only
    /// from `.alone` - this can never cut a wait short, and it must never
    /// end a shared break early.
    func clearCompany() {
        guard case .alone = company else { return }
        self.company = .idle
    }
    
    private func removeOwnWait(id: String) async {
        do {
            try await service.withdrawWait(id: id)
        } catch {
            // The sweep will get it. The rules let anyone clear a wait five
            // minutes after it expired, precisely for this.
            Log.presence.debug("Presence - could not remove the wait, leaving it to the sweep: \(error.localizedDescription)")
        }
    }
}
