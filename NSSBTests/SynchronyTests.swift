//
//  SynchronyTests.swift
//  NSSBTests
//

// Smoking together, driven end to end with no network: idle -> waiting ->
// together on one side, and idle -> taking somebody's free chair on the other.
//
// SimulatedPresenceService is the backend, and it deliberately never joins a
// wait by itself - so every arrival in this file is written by the test
// standing in for the other device. An invented cigarette that sits down and
// smokes a whole five minutes with you would be a lie about company, which is
// the one thing this layer exists to provide.

import XCTest
@testable import NSSB

@MainActor
final class SynchronyTests: XCTestCase {
    
    private var service: SimulatedPresenceService!
    private var repository: PresenceRepository!
    
    override func setUp() async throws {
        
        UserDefaults.standard.removeObject(forKey: "presence.liveBreakId")
        UserDefaults.standard.removeObject(forKey: "presence.liveBreakStart")
        
        service = SimulatedPresenceService()
        repository = PresenceRepository(service: service)
        await repository.start()
    }
    
    override func tearDown() async throws {
        BreakWait.window = 30
        BreakAsk.window = 8
        service = nil
        repository = nil
    }
    
    // MARK: - Waiting
    
    func testItStartsIdle() {
        XCTAssertEqual(repository.company, .idle)
    }
    
    func testWaitingPutsAnUnlitCigaretteOutThere() async throws {
        
        await repository.waitForCompany(design: design())
        
        let wait = try XCTUnwrap(repository.company.openWait)
        
        XCTAssertTrue(repository.company.isWaiting)
        XCTAssertEqual(wait.name, "Charcoal Gull")
        XCTAssertFalse(wait.paired)
        XCTAssertEqual(service.waitIds, [wait.id], "the wait should be the one document out there")
    }
    
    /// The rules reject an empty name outright, and a silent rejection would
    /// look exactly like nobody coming out.
    func testANamelessCigaretteIsNamedBeforeItWaits() async throws {
        
        await repository.waitForCompany(design: CigDesign())
        
        let wait = try XCTUnwrap(repository.company.openWait)
        XCTAssertFalse(wait.name.isEmpty)
    }
    
    func testYouCannotWaitTwice() async throws {
        
        await repository.waitForCompany(design: design())
        let first = try XCTUnwrap(repository.company.openWait)
        
        await repository.waitForCompany(design: design())
        
        XCTAssertEqual(repository.company.openWait?.id, first.id)
        XCTAssertEqual(service.waitIds.count, 1, "two unlit cigarettes of yours must never stand out there")
    }
    
    /// You cannot keep yourself company, and your own cigarette must never be
    /// drawn as a free chair.
    func testYourOwnWaitIsNeverCompany() async throws {
        
        await repository.waitForCompany(design: design())
        
        XCTAssertTrue(repository.waiting.isEmpty)
    }
    
    func testSomebodyElseWaitingShowsUp() async throws {
        
        await repository.waitForCompany(design: design())
        let theirs = try await strangerWaits()
        
        try await waitUntil("their cigarette to appear") {
            self.repository.waiting.map(\.id) == [theirs.id]
        }
    }
    
    // MARK: - Somebody comes out
    
    func testBeingJoinedLightsBothCigarettesAtOneInstant() async throws {
        
        await repository.waitForCompany(design: design())
        let mine = try XCTUnwrap(repository.company.openWait)
        
        let litAt = Date.now
        try await somebodyJoins(mine, as: "Paper Kestrel", at: litAt)
        
        try await waitUntil("the pairing to arrive") {
            self.repository.company.companion != nil
        }
        
        XCTAssertEqual(repository.company.companion?.name, "Paper Kestrel")
        XCTAssertEqual(repository.company.litAt, litAt,
                       "the break has to start at the shared instant, not at now")
    }
    
    /// The waiter owns the document, so clearing it is the waiter's job -
    /// and it has to go, or a second person could try to sit in a chair that
    /// is no longer free.
    func testAJoinedWaitIsCleanedUp() async throws {
        
        await repository.waitForCompany(design: design())
        let mine = try XCTUnwrap(repository.company.openWait)
        
        try await somebodyJoins(mine, as: "Paper Kestrel", at: .now)
        
        try await waitUntil("the wait to be withdrawn") {
            self.service.waitIds.isEmpty
        }
    }
    
    func testTheCourtyardIsDroppedOnceYouHaveCompany() async throws {
        
        await repository.waitForCompany(design: design())
        let mine = try XCTUnwrap(repository.company.openWait)
        _ = try await strangerWaits()
        
        try await somebodyJoins(mine, as: "Paper Kestrel", at: .now)
        
        try await waitUntil("the other waiters to be let go") {
            self.repository.waiting.isEmpty && self.repository.company.companion != nil
        }
    }
    
    // MARK: - Taking somebody's chair
    
    func testTakingAFreeChairStartsTheBreakForBoth() async throws {
        
        let theirs = try await strangerWaits()
        
        await repository.waitWith(theirs, design: design())
        
        XCTAssertEqual(repository.company.companion?.name, "Paper Kestrel")
        XCTAssertNotNil(repository.company.litAt)
        
        // Written where they can read it, which is the only way they learn
        // the instant to light at.
        let theirDocument = try await wait(theirs.id)
        XCTAssertTrue(theirDocument.paired)
        XCTAssertEqual(theirDocument.partnerName, "Charcoal Gull")
        XCTAssertEqual(theirDocument.litAt, repository.company.litAt)
    }
    
    func testYourOwnWaitIsWithdrawnWhenYouFindCompanyElsewhere() async throws {
        
        await repository.waitForCompany(design: design())
        let mine = try XCTUnwrap(repository.company.openWait)
        let theirs = try await strangerWaits()
        
        await repository.waitWith(theirs, design: design())
        
        XCTAssertFalse(service.waitIds.contains(mine.id),
                       "a chair nobody is sitting in must not be left out there")
    }
    
    /// The rules permit one pairing, so the server settles the race. The
    /// loser finds the chair taken, which is what would happen in a real
    /// courtyard too.
    func testTheSecondPersonToSitDownLoses() async throws {
        
        let theirs = try await strangerWaits()
        try await service.pairWith(
            id: theirs.id,
            partnerName: "Somebody Quicker",
            partnerDesign: design(title: "Somebody Quicker"),
            partnerCountry: "IE",
            partnerTzOffset: 0,
            litAt: .now
        )
        
        await repository.waitWith(theirs, design: design())
        
        XCTAssertEqual(repository.company, .idle, "losing costs you nothing but the chair")
        XCTAssertFalse(repository.waiting.contains { $0.id == theirs.id })
    }
    
    func testYouCannotJoinSomebodyWhileAlreadySmokingWithSomebody() async throws {
        
        let first = try await strangerWaits()
        await repository.waitWith(first, design: design())
        let companion = repository.company.companion
        
        let second = try await strangerWaits(named: "Hollow Lantern")
        await repository.waitWith(second, design: design())
        
        XCTAssertEqual(repository.company.companion, companion, "you only have one cigarette")
    }
    
    func testAnExpiredChairCannotBeTaken() async throws {
        
        BreakWait.window = 30
        let stale = BreakWait.opening(
            at: Date.now.addingTimeInterval(-40),
            uid: "a-stranger",
            design: design(title: "Paper Kestrel")
        )
        try await service.openWait(stale)
        
        await repository.waitWith(stale, design: design())
        
        XCTAssertEqual(repository.company, .idle)
    }
    
    // MARK: - Nobody comes
    
    func testThirtySecondsOfNobodyLeavesYouLightingYourOwn() async throws {
        
        BreakWait.window = 0.2
        
        await repository.waitForCompany(design: design())
        
        try await waitUntil("the wait to run out") {
            self.repository.company == .alone
        }

        // The line comes up first and the document goes afterwards - you are
        // told immediately and the bins are taken out behind it - so this
        // polls rather than asserting on the same tick.
        try await waitUntil("the chair to be cleared away") {
            self.service.waitIds.isEmpty
        }
    }
    
    func testTheLineClearsSoYouCanWaitAgain() async throws {
        
        BreakWait.window = 0.2
        await repository.waitForCompany(design: design())
        try await waitUntil("the wait to run out") { self.repository.company == .alone }
        
        repository.clearCompany()
        
        XCTAssertEqual(repository.company, .idle)
    }
    
    /// Clearing the line must never be able to end a shared break early.
    func testClearingCannotInterruptCompany() async throws {
        
        let theirs = try await strangerWaits()
        await repository.waitWith(theirs, design: design())
        
        repository.clearCompany()
        
        XCTAssertNotNil(repository.company.companion)
    }
    
    // MARK: - Leaving
    
    func testGoingBackInsideTakesTheChairWithYou() async throws {
        
        await repository.waitForCompany(design: design())
        
        await repository.cancelWait()
        
        XCTAssertEqual(repository.company, .idle)
        XCTAssertTrue(service.waitIds.isEmpty)
    }
    
    /// Lighting your own while still standing out there waiting. The wait has
    /// to come down, or somebody would give their five minutes to a chair
    /// that is already gone.
    func testLightingYourOwnEndsTheWait() async throws {
        
        await repository.waitForCompany(design: design())
        
        await repository.breakStarted(at: .now, design: design())
        
        XCTAssertFalse(repository.company.isWaiting)
        XCTAssertTrue(service.waitIds.isEmpty)
    }
    
    /// A break that begins *because* somebody joined must not cancel the
    /// pairing that caused it.
    func testTheSharedBreakSurvivesBeingPublished() async throws {
        
        let theirs = try await strangerWaits()
        await repository.waitWith(theirs, design: design())
        let litAt = try XCTUnwrap(repository.company.litAt)
        
        await repository.breakStarted(at: litAt, design: design())
        
        XCTAssertEqual(repository.company.companion?.name, "Paper Kestrel")
        XCTAssertEqual(repository.company.litAt, litAt)
    }
    
    /// Everything ends when the cigarette does, which is the first principle
    /// of the whole layer. Nothing about who you stood with is kept.
    func testCompanyEndsWithTheCigarette() async throws {
        
        let theirs = try await strangerWaits()
        await repository.waitWith(theirs, design: design())
        
        await repository.breakEnded()
        
        XCTAssertEqual(repository.company, .idle)
        XCTAssertTrue(repository.waiting.isEmpty)
    }
    
    // MARK: - Helpers
    
    // MARK: - Reaching out: one tap, both halves

    /// The split was never a human one. One tap has to put the question to
    /// everybody already lit and stand you out there for anybody unlit, or
    /// the person is picking between two mechanisms they never asked about.
    func testOneTapGoesOutBothWays() async throws {

        await repository.reachOut(design: design())

        XCTAssertNotNil(repository.ask.openAsk, "nothing was asked of the lit strangers")
        XCTAssertNotNil(repository.company.openWait, "nobody unlit could have joined")
    }

    func testTheRowShowsOneGestureWithTheLongerDeadline() async throws {

        await repository.reachOut(design: design())

        let wait = try XCTUnwrap(repository.company.openWait)

        // The wait outlives the ask, so the bar has to drain on its clock -
        // otherwise it empties while half the gesture is still running.
        XCTAssertEqual(repository.outreach, .reaching(until: wait.expiresAt))
    }

    /// The whole point of merging them. On its own an unanswered ask is a
    /// result worth saying out loud; inside a reach-out it is nothing, and
    /// announcing would light the cigarette with twenty seconds of wait left.
    func testAnUnansweredAskSaysNothingWhileTheWaitIsStillOut() async throws {

        BreakAsk.window = 0.3

        await repository.reachOut(design: design())
        let outgoing = try XCTUnwrap(repository.ask.openAsk)

        try await waitUntil("the ask to give up") { self.service.askIds.isEmpty }

        XCTAssertEqual(repository.ask, .idle, "the ask announced a result of its own")
        XCTAssertNotEqual(repository.outreach, .alone, "the cigarette would have been lit early")
        XCTAssertTrue(repository.company.isWaiting, "the wait should still be running")
        XCTAssertFalse(service.askIds.contains(outgoing.id), "the ask should have been taken down")
    }

    /// Asked on its own - no reach-out - it still announces, because then it
    /// really is the end of the gesture.
    func testAnUnansweredAskOnItsOwnStillAnnounces() async throws {

        BreakAsk.window = 0.3

        await repository.askForALight(design: design())
        try await waitUntil("the ask to give up") {
            self.repository.ask == .done(givenBy: nil)
        }

        XCTAssertEqual(repository.ask, .done(givenBy: nil))
        XCTAssertEqual(repository.outreach, .alone)
    }

    func testSomebodyComingOutTakesDownTheAsk() async throws {

        await repository.reachOut(design: design())

        let mine = try XCTUnwrap(repository.company.openWait)
        let litAt = Date.now
        try await somebodyJoins(mine, as: "Paper Kestrel", at: litAt)

        try await waitUntil("the pairing to land") {
            if case .together = self.repository.company { return true }
            return false
        }
        try await waitUntil("the ask to be withdrawn") {
            self.repository.ask.openAsk == nil
        }

        XCTAssertEqual(repository.ask, .idle, "a question was left standing for a light you have")
    }

    // MARK: - The person who lit you stays

    /// Somebody who stopped to light you was already burning. Winding their
    /// start back from the progress on the ask is the only thing that makes
    /// their cigarette shorter than yours, which is the honest picture.
    func testAGiverBurnsAheadOfYou() {

        let met = Date(timeIntervalSince1970: 1_000_000)
        var ask = BreakAsk.opening(uid: "me", design: design())
        ask.claimed = true
        ask.giverName = "Brass Kestrel"
        ask.giverDesign = design(title: "Brass Kestrel")
        ask.giverProgress = 0.4
        ask.giverCountry = "JP"
        ask.giverTzOffset = 32400

        let giver = AskGiver(ask)!
        let companion = Companion(giver: giver, metAt: met)

        XCTAssertEqual(companion.name, "Brass Kestrel")
        XCTAssertEqual(companion.country, "JP")
        XCTAssertEqual(companion.tzOffset, 32400)

        // Two fifths of five minutes ago.
        XCTAssertEqual(companion.startedAt.timeIntervalSince(met), -0.4 * Date.breakLength, accuracy: 0.01)
        XCTAssertEqual(companion.progress(at: met), 0.4, accuracy: 0.001)

        // And they go out before you do, by exactly what they had burned.
        XCTAssertTrue(companion.hasGone(at: met.addingTimeInterval(0.61 * Date.breakLength)))
        XCTAssertFalse(companion.hasGone(at: met.addingTimeInterval(0.59 * Date.breakLength)))
    }

    /// Two people who lit together share the instant exactly, so neither is
    /// ahead - this is the case that ends on the same second.
    func testPeopleWhoLitTogetherBurnAsOne() {

        let litAt = Date(timeIntervalSince1970: 1_000_000)
        let theirs = BreakWait.opening(uid: "them", design: design(title: "Paper Kestrel"))
        let companion = Companion(waiter: theirs, litAt: litAt)

        XCTAssertEqual(companion.startedAt, litAt)
        XCTAssertEqual(companion.progress(at: litAt.addingTimeInterval(Date.breakLength / 2)), 0.5, accuracy: 0.001)
        XCTAssertFalse(companion.hasGone(at: litAt.addingTimeInterval(Date.breakLength - 1)))
    }

    // MARK: - What the row says

    func testCompanyOutranksEverythingElse() async throws {

        await repository.reachOut(design: design())
        let mine = try XCTUnwrap(repository.company.openWait)
        let litAt = Date.now
        try await somebodyJoins(mine, as: "Paper Kestrel", at: litAt)

        try await waitUntil("the pairing to land") {
            if case .together = self.repository.company { return true }
            return false
        }

        guard case .together(let companion) = repository.outreach else {
            return XCTFail("the row is not naming the person standing next to you")
        }
        XCTAssertEqual(companion.name, "Paper Kestrel")
    }

    func testAnIdleRepositoryOffersTheOneThing() {
        XCTAssertEqual(repository.outreach, .idle)
    }

    private func design(title: String = "Charcoal Gull") -> CigDesign {
        var design = CigDesign()
        design.title = title
        return design
    }
    
    /// Somebody else standing out there with an unlit cigarette.
    private func strangerWaits(named name: String = "Paper Kestrel") async throws -> BreakWait {
        let theirs = BreakWait.opening(uid: "a-stranger", design: design(title: name))
        try await service.openWait(theirs)
        return theirs
    }
    
    /// The other device sitting down, which is the only thing that can.
    private func somebodyJoins(_ wait: BreakWait, as name: String, at litAt: Date) async throws {
        try await service.pairWith(
            id: wait.id,
            partnerName: name,
            partnerDesign: design(title: name),
            partnerCountry: "JP",
            partnerTzOffset: 32400,
            litAt: litAt
        )
    }
    
    private func wait(_ id: String) async throws -> BreakWait {
        var found: BreakWait?
        service.observeOwnWait(id: id) { found = $0 }
        service.stopObservingOwnWait()
        return try XCTUnwrap(found, "no wait \(id)")
    }
    
    private func waitUntil(
        _ what: String,
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) async throws {
        
        let deadline = Date.now.addingTimeInterval(timeout)
        
        while Date.now < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        
        XCTFail("timed out waiting for \(what)")
    }
}
