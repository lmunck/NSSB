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
            self.repository.company.companions.first != nil
        }
        
        XCTAssertEqual(repository.company.companions.first?.name, "Paper Kestrel")
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
            self.repository.waiting.isEmpty && self.repository.company.companions.first != nil
        }
    }
    
    // MARK: - Taking somebody's chair
    
    func testTakingAFreeChairStartsTheBreakForBoth() async throws {
        
        let theirs = try await strangerWaits()
        
        await repository.waitWith(theirs, design: design())
        
        XCTAssertEqual(repository.company.companions.first?.name, "Paper Kestrel")
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
        let companion = repository.company.companions.first
        
        let second = try await strangerWaits(named: "Hollow Lantern")
        await repository.waitWith(second, design: design())
        
        XCTAssertEqual(repository.company.companions.first, companion, "you only have one cigarette")
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
        
        XCTAssertNotNil(repository.company.companions.first)
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
        
        XCTAssertEqual(repository.company.companions.first?.name, "Paper Kestrel")
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

        guard case .together(let companions) = repository.outreach else {
            return XCTFail("the row is not naming the person standing next to you")
        }
        XCTAssertEqual(companions.map(\.name), ["Paper Kestrel"])
    }

    // MARK: - How they arrive

    /// The two kinds of company look different on screen because they are
    /// different: one walks over from your lit end, the other was never near
    /// it. The state has to be able to tell them apart without being told.
    func testTheStateKnowsWhichKindOfCompanyThisIs() {

        let met = Date(timeIntervalSince1970: 1_000_000)

        var ask = BreakAsk.opening(uid: "me", design: design())
        ask.claimed = true
        ask.giverName = "Brass Kestrel"
        ask.giverProgress = 0.4
        let lighter = Companion(giver: AskGiver(ask)!, metAt: met)

        XCTAssertTrue(lighter.metAtYourTip(whenYouLitAt: met))

        let theirs = BreakWait.opening(uid: "them", design: design(title: "Paper Kestrel"))
        let equal = Companion(waiter: theirs, litAt: met)

        XCTAssertFalse(equal.metAtYourTip(whenYouLitAt: met))
        XCTAssertFalse(false)
    }

    /// A giver who had barely started is still a giver, not a twin - the
    /// slack is for clock jitter, not for a real head start.
    func testASecondOfJitterIsNotAHeadStart() {

        let met = Date(timeIntervalSince1970: 1_000_000)
        let theirs = BreakWait.opening(uid: "them", design: design())
        let nearlyEqual = Companion(waiter: theirs, litAt: met.addingTimeInterval(-0.4))

        XCTAssertFalse(nearlyEqual.metAtYourTip(whenYouLitAt: met))
    }

    // MARK: - The count

    /// A listener that has attached but not spoken is not an empty
    /// courtyard. Saying so put "quiet out here right now" on screen with a
    /// stranger's cigarette about to appear behind it.
    func testAnAttachedListenerIsNotAnEmptyCourtyard() async throws {

        await repository.breakStarted(at: .now, design: design())

        XCTAssertNotEqual(repository.othersCount, 0,
                          "the courtyard was called empty before it had been looked at")
    }

    func testAnIdleRepositoryOffersTheOneThing() {
        XCTAssertEqual(repository.outreach, .idle)
    }

    /// Reported from a phone: the second one appeared and then vanished.
    /// The still picture of two companions is correct, so whatever removes
    /// them is something that happens afterwards rather than a layout fault.
    /// This holds the whole sequence still and then waits, which is the only
    /// way a departure timer firing early would show up.
    func testTheSecondOneIsStillThereASecondLater() async throws {

        await repository.reachOut(design: design())
        let mine = try XCTUnwrap(repository.company.openWait)
        try await somebodyJoins(mine, as: "Paper Kestrel", at: .now)
        try await waitUntil("the pairing") { self.repository.company.companions.count == 1 }

        await repository.breakStarted(at: .now, design: design())

        let theirs = try await strangerAsks(named: "Quiet Sparrow")
        try await waitUntil("their ask") { self.repository.offers.isEmpty == false }

        await repository.offerLight(to: theirs)
        repository.offerFinished()

        XCTAssertEqual(repository.company.companions.count, 2, "they never arrived")

        try await Task.sleep(nanoseconds: 1_500_000_000)

        XCTAssertEqual(repository.company.companions.count, 2,
                       "somebody left who had only just got here")
        XCTAssertEqual(repository.giving, nil, "the handoff never finished")
    }

    /// The other order: you light somebody first, then get paired.
    func testLightingSomebodyFirstStillLeavesRoomForAPairing() async throws {

        await repository.breakStarted(at: .now, design: design())

        let theirs = try await strangerAsks(named: "Quiet Sparrow")
        try await waitUntil("their ask") { self.repository.offers.isEmpty == false }
        await repository.offerLight(to: theirs)
        repository.offerFinished()

        XCTAssertEqual(repository.company.companions.count, 1)

        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertEqual(repository.company.companions.count, 1,
                       "the only person out here left after a second")
    }

    // MARK: - Where somebody will stand, asked before they get there

    private func companion(_ name: String, startedAt: Date) -> Companion {
        Companion(waiter: BreakWait.opening(uid: "x", design: design(title: name)),
                  litAt: startedAt)
    }

    /// The walk over and the place they stop have to be the same side. They
    /// were worked out separately, and the giving handoff took its direction
    /// from the ask's uuid - a hash with nothing to do with the person - so
    /// somebody could cross the screen to stand where they came from, or
    /// land on top of whoever was already there.
    func testAskingWhereSomebodyWillStandMatchesWhereTheyDo() {

        let now = Date(timeIntervalSince1970: 1_000_000)

        let asked = CompanyState.idle.sideFor("Paper Kestrel")
        let one = CompanyState.idle.standing(with: companion("Paper Kestrel", startedAt: now), since: now)

        XCTAssertEqual(one.companions[0].side, asked, "they did not stand where they were walking")

        let askedAgain = one.sideFor("Quiet Sparrow")
        let two = one.standing(with: companion("Quiet Sparrow", startedAt: now), since: now)

        XCTAssertEqual(two.companions[1].side, askedAgain)
    }

    func testTheSecondPersonTakesTheOtherSide() {

        let now = Date(timeIntervalSince1970: 1_000_000)

        let two = CompanyState.idle
            .standing(with: companion("Paper Kestrel", startedAt: now), since: now)
            .standing(with: companion("Quiet Sparrow", startedAt: now), since: now)

        XCTAssertEqual(two.companions.count, 2)
        XCTAssertNotEqual(two.companions[0].side, two.companions[1].side,
                          "they cannot stand in the same place")
        XCTAssertEqual(two.companions[0].side, Companion.naturalSide(for: "Paper Kestrel"),
                       "whoever got here first keeps the side they would have had")
        XCTAssertTrue(two.isFull)
    }

    func testThereIsNoRoomForAThird() {

        let now = Date(timeIntervalSince1970: 1_000_000)
        let two = CompanyState.idle
            .standing(with: companion("Paper Kestrel", startedAt: now), since: now)
            .standing(with: companion("Quiet Sparrow", startedAt: now), since: now)

        let three = two.standing(with: companion("Brass Kestrel", startedAt: now), since: now)

        XCTAssertEqual(three.companions.count, 2, "there are only two sides of a person")
        XCTAssertEqual(three.companions.map(\.name), ["Paper Kestrel", "Quiet Sparrow"])
    }

    /// Whoever finishes first goes in alone, and nobody shuffles across to
    /// take the empty side.
    func testOneCanLeaveWithoutMovingTheOther() {

        let now = Date(timeIntervalSince1970: 1_000_000)
        let two = CompanyState.idle
            .standing(with: companion("Paper Kestrel", startedAt: now), since: now)
            .standing(with: companion("Quiet Sparrow", startedAt: now), since: now)

        let theirSide = two.companions[1].side
        let one = two.without("Paper Kestrel")

        XCTAssertEqual(one.companions.map(\.name), ["Quiet Sparrow"])
        XCTAssertEqual(one.companions[0].side, theirSide, "they should not have slid over")
        XCTAssertEqual(one.litAt, now, "the break did not restart because somebody left")

        XCTAssertEqual(one.without("Quiet Sparrow"), .idle, "the last one out leaves you alone")
    }

    func testTheSamePersonCannotStandWithYouTwice() {

        let now = Date(timeIntervalSince1970: 1_000_000)
        let once = CompanyState.idle.standing(with: companion("Paper Kestrel", startedAt: now), since: now)
        let twice = once.standing(with: companion("Paper Kestrel", startedAt: now), since: now)

        XCTAssertEqual(twice.companions.count, 1)
    }

    // MARK: - Whoever has burned longest goes in first

    /// The one rule the whole layer runs on. Somebody who lit you started
    /// before you; somebody you lit started after; two who lit together
    /// started at the same instant and end on the same second.
    func testTheThreeWaysOfMeetingBurnInTheRightOrder() {

        let met = Date(timeIntervalSince1970: 1_000_000)

        var ask = BreakAsk.opening(uid: "me", design: design())
        ask.claimed = true
        ask.giverName = "Brass Kestrel"
        ask.giverProgress = 0.4
        let whoLitYou = Companion(giver: AskGiver(ask)!, metAt: met)

        let whoYouLit = Companion(lit: BreakAsk.opening(uid: "them", design: design(title: "Quiet Sparrow")), at: met)

        let whoLitWithYou = Companion(waiter: BreakWait.opening(uid: "them", design: design(title: "Paper Kestrel")), litAt: met)

        XCTAssertGreaterThan(whoLitYou.progress(at: met), whoLitWithYou.progress(at: met),
                             "somebody who lit you is ahead of you")
        XCTAssertEqual(whoYouLit.progress(at: met), 0, accuracy: 0.001,
                       "somebody you just lit has their whole cigarette")
        XCTAssertEqual(whoLitWithYou.progress(at: met), 0, accuracy: 0.001)

        // And only the two who lit together were never tip to tip.
        XCTAssertTrue(whoLitYou.metAtYourTip(whenYouLitAt: met))
        XCTAssertFalse(whoLitWithYou.metAtYourTip(whenYouLitAt: met))

        // You lit them a while into your own break, so they are behind you.
        let late = met.addingTimeInterval(120)
        let lateOne = Companion(lit: BreakAsk.opening(uid: "them", design: design(title: "Quiet Sparrow")), at: late)
        XCTAssertTrue(lateOne.metAtYourTip(whenYouLitAt: met))
        XCTAssertFalse(lateOne.hasGone(at: met.addingTimeInterval(Date.breakLength)),
                       "they are still out here after you have gone in")
    }

    // MARK: - The count

    /// Somebody standing right there asking is present. They just have not
    /// got their cigarette going yet.
    func testPeopleWhoAreOutButUnlitAreCounted() async throws {

        await repository.breakStarted(at: .now, design: design())

        try await waitUntil("the courtyard to be looked at") { self.repository.othersCount != nil }
        let lit = try XCTUnwrap(repository.othersCount)

        try await strangerAsks()
        try await waitUntil("their ask to arrive") { self.repository.offers.isEmpty == false }

        XCTAssertEqual(repository.othersCount, lit + 1,
                       "an unlit cigarette in the courtyard is still somebody out here")
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
    
    /// Somebody else standing out there with an unlit cigarette, asking.
    @discardableResult
    private func strangerAsks(named name: String = "Quiet Sparrow") async throws -> BreakAsk {
        let theirs = BreakAsk.opening(uid: "a-stranger", design: design(title: name))
        try await service.openAsk(theirs)
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

// MARK: - Seeing it

import SwiftUI

/// Renders the views to PNG files on the host, so they can be looked at.
///
/// The simulator's automation panel does not work on this machine - it goes
/// looking for a CoreSimulator framework at a path Xcode 27 no longer uses -
/// so there is no way to tap through the app and watch what happens. Several
/// rounds of drawing bugs were fixed blind before this existed, which is how
/// a companion ended up correctly placed and completely invisible.
///
/// This is not a substitute for using the app. It renders one view at a time
/// with no animation running, which answers "is it there, and where" and
/// nothing about motion.
///
/// Skipped unless asked for, because it writes files:
///
///     xcodebuild test -scheme NSSB \
///       -destination 'platform=iOS Simulator,id=<udid>' \
///       -only-testing:NSSBTests/RenderTests \
///       TEST_RUNNER_NSSB_RENDER=/path/to/write/to
///
/// The TEST_RUNNER_ prefix is not optional - xcodebuild does not pass its own
/// environment to the test process, and a variable without it silently never
/// arrives, which looks exactly like the tests passing.
@MainActor
final class RenderTests: XCTestCase {

    private var out: URL!

    override func setUpWithError() throws {
        // The simulator's temp directory is a real directory on this Mac,
        // so the path printed below can be opened from outside. No build
        // setting to forward and nothing to remember to pass.
        out = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("nssb-render", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        print("rendering into \(out.path)")
    }

    private func render(_ name: String, size: CGSize, @ViewBuilder _ content: () -> some View) throws {

        let view = content()
            .frame(width: size.width, height: size.height)
            .background(Color.black)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        let image = try XCTUnwrap(renderer.uiImage, "\(name) rendered to nothing")
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: out.appendingPathComponent("\(name).png"))
        print("rendered \(name).png — \(Int(size.width))x\(Int(size.height))")
    }

    // The phone's proportions, so the numbers mean what they mean in the app.
    private let screen = CGSize(width: 402, height: 874)
    private var cigHeight: CGFloat { screen.height * 0.7 }
    private var cigWidth: CGFloat { screen.width * 0.2 }

    private func design(_ title: String, body: Color, filter: Color, glow: Color, background: Color) -> CigDesign {
        var d = CigDesign()
        d.title = title
        d.body = body
        d.filter = filter
        d.glow = glow
        d.background = background
        return d
    }

    private var mine: CigDesign {
        design("Sunlit Parchment", body: .white, filter: Color(red: 1, green: 0.8, blue: 0.5),
               glow: Color(hue: 0.04, saturation: 1, brightness: 1), background: .blue)
    }

    private func companion(_ name: String, startedAt: Date) -> Companion {
        var wait = BreakWait.opening(uid: "x", design: design(name, body: Color(red: 0.78, green: 0.76, blue: 0.72),
                                                              filter: Color(red: 0.86, green: 0.55, blue: 0.18),
                                                              glow: Color(red: 1, green: 0.35, blue: 0.05),
                                                              background: Color(red: 0.85, green: 0.42, blue: 0.12)))
        wait.paired = true
        return Companion(waiter: wait, litAt: startedAt)
    }

    /// The whole composition: your cigarette in the middle with whoever is
    /// standing with you drawn in the same frame, exactly as ContentView
    /// lays it out.
    private func courtyard(_ companions: [Companion], yourProgress: Double) -> some View {

        let height = cigHeight
        let mineWidth = height * mine.widthPercentage

        // Exactly how ContentView puts it together: your own cigarette in
        // its frame, with everybody else in an overlay on top of it. The
        // structure is the point - a bare ForEach straight into .overlay
        // behaves differently from one inside a ZStack, and this harness is
        // worthless if it quietly builds the more forgiving of the two.
        return DistantCigaretteView(design: mine, progress: yourProgress, height: height)
            .frame(width: cigWidth, height: height)
            .overlay {
                ForEach(companions, id: \.name) { companion in
                    let side: CGFloat = companion.side == .left ? -1 : 1
                    let theirs = height * companion.design.widthPercentage
                    let rest = mineWidth / 2 + 52 + theirs / 2
                    CompanionCigaretteView(
                        companion: companion,
                        height: height,
                        mirrored: side < 0,
                        restingOffset: rest,
                        arrived: true
                    )
                    .offset(x: side * rest, y: 0)
                }
            }
    }

    func testRenderNobodyOneAndTwo() throws {

        let now = Date.now
        let first = companion("Paper Kestrel", startedAt: now)

        let one = CompanyState.idle.standing(with: first, since: now)
        let two = one.standing(with: companion("Quiet Sparrow", startedAt: now), since: now)

        try render("company-0", size: screen) { courtyard([], yourProgress: 0.3) }
        try render("company-1", size: screen) { courtyard(one.companions, yourProgress: 0.3) }
        try render("company-2", size: screen) { courtyard(two.companions, yourProgress: 0.3) }

        // The sides the model actually chose, printed so the picture can be
        // checked against the thing that decided it.
        for c in two.companions { print("  \(c.name) stands \(c.side)") }
    }

    func testRenderTheRow() throws {

        let now = Date.now
        let one = CompanyState.idle.standing(with: companion("Paper Kestrel", startedAt: now), since: now)
        let two = one.standing(with: companion("Quiet Sparrow", startedAt: now), since: now)
        let wait = BreakWait.opening(uid: "me", design: mine)

        let row = CGSize(width: 402, height: 44)

        try render("row-idle", size: row) {
            ReachOutView(state: .idle, unlit: true, reach: {}, clear: {})
        }
        try render("row-reaching", size: row) {
            ReachOutView(state: .reaching(until: wait.expiresAt), unlit: true, reach: {}, clear: {})
        }
        try render("row-one", size: row) {
            ReachOutView(state: .together(one.companions), unlit: false, reach: {}, clear: {})
        }
        try render("row-two", size: row) {
            ReachOutView(state: .together(two.companions), unlit: false, reach: {}, clear: {})
        }
        try render("row-alone", size: row) {
            ReachOutView(state: .alone, unlit: true, reach: {}, clear: {})
        }
    }
}

/// Runs a view for real and photographs it as it goes.
///
/// ImageRenderer draws a view once with nothing running - no onAppear, no
/// task, no timers - which answers "where is it" and nothing about what
/// happens next. A companion that arrives correctly and then vanishes looks
/// perfect to it. So this puts the view in an actual window with an actual
/// runloop, lets time pass, and takes a photograph whenever asked.
///
/// This is the closest thing to using the app that exists on this machine:
/// the simulator's automation panel cannot attach, because it looks for a
/// CoreSimulator framework at a path Xcode 27 no longer uses.
@MainActor
final class LiveViewTests: XCTestCase {

    private var window: UIWindow!
    private var out: URL!

    override func setUpWithError() throws {
        out = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("nssb-live", isDirectory: true)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        print("filming into \(out.path)")
    }

    override func tearDown() async throws {
        window?.isHidden = true
        window = nil
    }

    private func show(_ view: some View, size: CGSize) {
        window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = UIHostingController(rootView:
            view.frame(width: size.width, height: size.height).background(Color.black)
        )
        window.rootViewController?.view.backgroundColor = .black
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
    }

    @discardableResult
    private func frame(_ name: String) throws -> UIImage {
        // drawHierarchy needs a real screen update and comes back black in a
        // test bundle. Rendering the layer tree works headless, and the
        // presentation layer is what is actually on screen this instant -
        // mid-animation included, which is the point of filming at all.
        // The hosting view has to be asked to lay out: a companion added
        // after the window was shown otherwise never gets a layout pass
        // here, and the overlay renders as nothing.
        window.rootViewController?.view.setNeedsLayout()
        window.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { ctx in
            window.layer.render(in: ctx.cgContext)
        }
        try XCTUnwrap(image.pngData()).write(to: out.appendingPathComponent("\(name).png"))
        return image
    }

    /// Roughly how much of the frame is not black, per vertical third of the
    /// width. Enough to say "somebody is on the left and somebody is on the
    /// right" without looking, so a regression can fail the test rather than
    /// wait for somebody to notice a picture.
    private func brightness(_ image: UIImage) -> (left: Double, middle: Double, right: Double) {

        guard let cg = image.cgImage else { return (0, 0, 0) }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var sums = [0.0, 0.0, 0.0]
        for y in stride(from: 0, to: h, by: 4) {
            for x in stride(from: 0, to: w, by: 4) {
                let i = (y * w + x) * 4
                let v = (Double(pixels[i]) + Double(pixels[i + 1]) + Double(pixels[i + 2])) / 765
                sums[min(2, x * 3 / w)] += v
            }
        }
        let n = Double((h / 4) * (w / 4)) / 3
        return (sums[0] / n, sums[1] / n, sums[2] / n)
    }

    // MARK: The experiment

    /// Exactly what was reported: one person already standing with you, a
    /// second arrives, and the second disappears.
    func testASecondCompanionArrivesAndStays() async throws {

        let stage = Stage()
        let size = CGSize(width: 402, height: 874)

        show(CompanionStageView(stage: stage, size: size), size: size)
        try await settle(0.3)

        stage.company = stage.company.standing(with: stage.someone("Paper Kestrel"), since: .now)
        try await settle(1.2)
        let one = try frame("live-1-only")

        stage.company = stage.company.standing(with: stage.someone("Quiet Sparrow"), since: .now)
        try await settle(0.15)
        try frame("live-2-arriving")
        try await settle(1.2)
        let two = try frame("live-2-settled")
        try await settle(2.5)
        let later = try frame("live-2-later")

        let sides = stage.company.companions.map(\.side)
        print("  sides: \(sides)")

        let b1 = brightness(one), b2 = brightness(two), b3 = brightness(later)
        print(String(format: "  one      L%.3f M%.3f R%.3f", b1.left, b1.middle, b1.right))
        print(String(format: "  two      L%.3f M%.3f R%.3f", b2.left, b2.middle, b2.right))
        print(String(format: "  2.5s on  L%.3f M%.3f R%.3f", b3.left, b3.middle, b3.right))

        XCTAssertEqual(stage.company.companions.count, 2)
        XCTAssertGreaterThan(b2.left, 0.01, "nobody on the left")
        XCTAssertGreaterThan(b2.right, 0.01, "nobody on the right")
        XCTAssertGreaterThan(b3.left, 0.01, "the left one vanished")
        XCTAssertGreaterThan(b3.right, 0.01, "the right one vanished")
    }

    /// Somebody you stopped to light walks out from your tip. The motion
    /// is the whole of it - without it they teleport into place - so this
    /// photographs the same arrival twice and insists the two differ.
    func testTheArrivalActuallyMoves() async throws {

        let stage = Stage()
        let size = CGSize(width: 402, height: 874)

        show(CompanionStageView(stage: stage, size: size, arrival: .fromYourTip), size: size)
        try await settle(0.3)

        stage.company = stage.company.standing(with: stage.someone("Brass Kestrel"), since: .now)

        try await settle(0.1)
        let early = brightness(try frame("walk-early"))
        try await settle(1.0)
        let late = brightness(try frame("walk-late"))

        print(String(format: "  early L%.3f M%.3f R%.3f", early.left, early.middle, early.right))
        print(String(format: "  late  L%.3f M%.3f R%.3f", late.left, late.middle, late.right))

        // They end up on one side; early on they are still nearer the
        // middle and smaller, so the two frames cannot be identical.
        let movedLeft = abs(late.left - early.left)
        let movedRight = abs(late.right - early.right)
        XCTAssertGreaterThan(max(movedLeft, movedRight), 0.004,
                             "they arrived without moving - the walk was swallowed again")
        XCTAssertGreaterThan(max(late.left, late.right), 0.01, "nobody is standing there")
    }

    /// The last gap: the real repository driving the real view.
    ///
    /// Everything else tests one or the other. The reported fault - a second
    /// companion that arrives and then vanishes - could live in the seam, so
    /// this runs the actual sequence through PresenceRepository with the
    /// view watching, and keeps watching afterwards.
    func testTheWholeSequenceThroughTheRealRepository() async throws {

        UserDefaults.standard.removeObject(forKey: "presence.liveBreakId")
        UserDefaults.standard.removeObject(forKey: "presence.liveBreakStart")

        let service = SimulatedPresenceService()
        let repository = PresenceRepository(service: service)
        await repository.start()

        let size = CGSize(width: 402, height: 874)
        show(CourtyardStageView(presence: repository, size: size), size: size)
        try await settle(0.3)

        var design = CigDesign()
        design.title = "Sunlit Parchment"

        // Somebody takes your chair.
        await repository.reachOut(design: design)
        let mine = try XCTUnwrap(repository.company.openWait)
        try await service.pairWith(id: mine.id, partnerName: "Paper Kestrel",
                                   partnerDesign: design, partnerCountry: "JP",
                                   partnerTzOffset: 32400, litAt: .now)
        try await settle(1.0)
        let one = brightness(try frame("real-1"))

        await repository.breakStarted(at: .now, design: design)
        try await settle(0.4)

        // And then you light somebody.
        var sparrow = CigDesign()
        sparrow.title = "Quiet Sparrow"
        let theirs = BreakAsk.opening(uid: "a-stranger", design: sparrow)
        try await service.openAsk(theirs)
        try await settle(0.3)
        await repository.offerLight(to: theirs)
        repository.offerFinished()

        try await settle(1.2)
        let two = brightness(try frame("real-2"))
        try await settle(3.0)
        let later = brightness(try frame("real-2-later"))

        print("  companions: \(repository.company.companions.map { "\($0.name)/\($0.side)" })")
        print(String(format: "  one   L%.3f R%.3f", one.left, one.right))
        print(String(format: "  two   L%.3f R%.3f", two.left, two.right))
        print(String(format: "  +3s   L%.3f R%.3f", later.left, later.right))

        XCTAssertEqual(repository.company.companions.count, 2)
        XCTAssertGreaterThan(min(two.left, two.right), 0.01, "one of them never drew")
        XCTAssertGreaterThan(min(later.left, later.right), 0.01,
                             "somebody vanished three seconds after arriving")
    }

    private func settle(_ seconds: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}


/// A changeable `CompanyState` for the live harness, so a companion can be
/// made to arrive while the view is on screen rather than being there from
/// the first frame - which is the whole difference that matters.
@MainActor
final class Stage: ObservableObject {

    @Published var company: CompanyState = .idle

    func someone(_ name: String) -> Companion {
        var d = CigDesign()
        d.title = name
        d.body = Color(red: 0.78, green: 0.76, blue: 0.72)
        d.filter = Color(red: 0.86, green: 0.55, blue: 0.18)
        d.glow = Color(red: 1, green: 0.35, blue: 0.05)
        d.background = Color(red: 0.85, green: 0.42, blue: 0.12)
        var wait = BreakWait.opening(uid: "x", design: d)
        wait.paired = true
        return Companion(waiter: wait, litAt: .now)
    }
}

/// ContentView's arrangement, with nothing else on screen.
struct CompanionStageView: View {

    @ObservedObject var stage: Stage
    let size: CGSize
    var arrival: CompanionArrival = .fromTheDark

    var body: some View {

        let height = size.height * 0.7
        let width = size.width * 0.2
        var mine = CigDesign()
        let _ = { mine.title = "Sunlit Parchment" }()

        return DistantCigaretteView(design: mine, progress: 0.3, height: height)
            .frame(width: width, height: height)
            .overlay {
                ForEach(stage.company.companions, id: \.name) { companion in
                    let side: CGFloat = companion.side == .left ? -1 : 1
                    let theirs = height * companion.design.widthPercentage
                    let rest = height * mine.widthPercentage / 2 + 52 + theirs / 2
                    CompanionCigaretteView(
                        companion: companion,
                        height: height,
                        mirrored: side < 0,
                        arrival: arrival,
                        restingOffset: rest
                    )
                    .offset(x: side * rest, y: 0)
                }
            }
            .frame(width: size.width, height: size.height)
    }
}


/// ContentView's cigarette frame, fed by a real repository.
struct CourtyardStageView: View {

    @ObservedObject var presence: PresenceRepository
    let size: CGSize

    var body: some View {

        let height = size.height * 0.7
        let width = size.width * 0.2
        let mine = CigDesign()

        return DistantCigaretteView(design: mine, progress: 0.3, height: height)
            .frame(width: width, height: height)
            .overlay {
                ForEach(presence.company.companions, id: \.name) { companion in
                    let side: CGFloat = companion.side == .left ? -1 : 1
                    let theirs = height * companion.design.widthPercentage
                    let rest = height * mine.widthPercentage / 2 + 52 + theirs / 2
                    CompanionCigaretteView(
                        companion: companion,
                        height: height,
                        mirrored: side < 0,
                        arrival: companion.metAtYourTip(whenYouLitAt: presence.company.litAt ?? .now)
                            ? .fromYourTip : .fromTheDark,
                        restingOffset: rest
                    )
                    .offset(x: side * rest, y: 0)
                }
            }
            .frame(width: size.width, height: size.height)
    }
}
