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
        let one = two.without(two.companions[0].id)

        XCTAssertEqual(one.companions.map(\.name), ["Quiet Sparrow"])
        XCTAssertEqual(one.companions[0].side, theirSide, "they should not have slid over")
        XCTAssertEqual(one.litAt, now, "the break did not restart because somebody left")

        XCTAssertEqual(one.without(one.companions[0].id), .idle, "the last one out leaves you alone")
    }

    func testTheSamePersonCannotStandWithYouTwice() {

        let now = Date(timeIntervalSince1970: 1_000_000)
        let them = companion("Paper Kestrel", startedAt: now)
        let twice = CompanyState.idle
            .standing(with: them, since: now)
            .standing(with: them, since: now)

        XCTAssertEqual(twice.companions.count, 1)
    }

    /// Two people can draw the same two words out of the hat, and the same
    /// person coming back out with a fresh cigarette certainly has.
    ///
    /// All of this used to be keyed on the name, which made them one entry:
    /// standing next to somebody while they asked the courtyard for a light
    /// again replaced the one beside you with the one walking over, and put
    /// them on the other side on the way.
    func testTwoPeopleOfTheSameNameAreTwoPeople() {

        let now = Date(timeIntervalSince1970: 1_000_000)
        let first = companion("Quiet Sparrow", startedAt: now)
        let again = companion("Quiet Sparrow", startedAt: now)

        XCTAssertNotEqual(first.id, again.id, "two cigarettes, two documents")

        let both = CompanyState.idle
            .standing(with: first, since: now)
            .standing(with: again, since: now)

        XCTAssertEqual(both.companions.count, 2, "one of them was mistaken for the other")
        XCTAssertNotEqual(both.companions[0].side, both.companions[1].side,
                          "they ended up standing in the same place")
    }

    /// With both sides of you taken, there is nowhere to put anybody - and
    /// the answer to which side is the one they came from, so they lean in
    /// from where they are standing rather than from across you.
    func testWithNoRoomLeftTheSideIsSimplyWhereTheyCameFrom() {

        let now = Date(timeIntervalSince1970: 1_000_000)
        let two = CompanyState.idle
            .standing(with: companion("Paper Kestrel", startedAt: now), since: now)
            .standing(with: companion("Quiet Sparrow", startedAt: now), since: now)

        XCTAssertTrue(two.isFull)

        for name in ["Brass Kestrel", "Hollow Lantern", "Sunlit Parchment"] {
            XCTAssertEqual(two.sideFor(name), Companion.naturalSide(for: name),
                           "\(name) was sent to the far side of a full house")
        }
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
    ///
    /// Through the app's own overlay rather than a copy of it. This used to
    /// rebuild the arrangement by hand, which made the harness a second
    /// implementation of the thing it was supposed to be checking - and a
    /// second implementation cannot catch a mistake in the first.
    private func courtyard(_ companions: [Companion], yourProgress: Double) -> some View {

        let height = cigHeight

        return DistantCigaretteView(design: mine, progress: yourProgress, height: height)
            .frame(width: cigWidth, height: height)
            .overlay {
                BesideYouView(
                    people: companions.map { standing($0) },
                    mine: mine,
                    height: height,
                    yourProgress: yourProgress,
                    courtyard: screen,
                    settled: true
                )
            }
            .frame(width: screen.width, height: screen.height)
            .coordinateSpace(name: Courtyard.space)
    }

    /// Somebody already standing there, at the spot they came from.
    private func standing(_ companion: Companion) -> Visitor {
        let spot = Courtyard.position(for: companion.name)
        return Visitor(companion: companion,
                       from: CGPoint(x: spot.x, y: spot.y),
                       depth: spot.depth,
                       handoff: nil)
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
        // Whatever a test stretched the journey to, the next one starts at
        // the app's own speed.
        VisitorCigaretteView.pace = 1
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

    /// A photograph of the window as it is this instant.
    ///
    /// Writing the PNG is optional, and filming leaves it out: measuring one
    /// frame costs about a second in a debug build, which is slower than the
    /// thing being filmed. So a film captures first and measures afterwards,
    /// and only the frames worth looking at are written out.
    @discardableResult
    private func frame(_ name: String? = nil) throws -> UIImage {
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

        // One pixel per point. At the device's own scale a phone-sized
        // window costs about a second to render and another to measure,
        // which is slower than the animation being filmed - and nothing
        // here is looking at a pixel.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        let image = renderer.image { ctx in
            window.layer.render(in: ctx.cgContext)
        }
        if let name = name { try save(image, name) }
        return image
    }

    private func save(_ image: UIImage, _ name: String) throws {
        try XCTUnwrap(image.pngData()).write(to: out.appendingPathComponent("\(name).png"))
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

    private func pixels(_ image: UIImage) -> (bytes: [UInt8], w: Int, h: Int)? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (bytes, w, h)
    }

    /// Where the visitor is, and how much of them there is, worked out by
    /// taking away the frame with nobody in it.
    ///
    /// Your own cigarette sits in the middle of the screen and outweighs
    /// everybody, so it has to be subtracted rather than worked around. What
    /// is left is one person, and following them frame by frame is the only
    /// way to tell a walk from a jump.
    private func whereabouts(_ image: UIImage,
                             without baseline: UIImage) -> Whereabouts {

        guard let now = pixels(image), let was = pixels(baseline),
              now.w == was.w, now.h == was.h else { return Whereabouts() }

        var light = 0.0, sumX = 0.0, sumY = 0.0
        var reach = 1.0

        for y in stride(from: 0, to: now.h, by: 2) {
            for x in stride(from: 0, to: now.w, by: 2) {
                let i = (y * now.w + x) * 4
                let a = (Double(now.bytes[i]) + Double(now.bytes[i + 1]) + Double(now.bytes[i + 2])) / 765
                let b = (Double(was.bytes[i]) + Double(was.bytes[i + 1]) + Double(was.bytes[i + 2])) / 765
                let d = max(0, a - b)
                guard d > 0.02 else { continue }
                light += d
                let fx = Double(x) / Double(now.w)
                sumX += d * fx
                sumY += d * Double(y) / Double(now.h)
                reach = min(reach, fx)
            }
        }

        guard light > 0 else { return Whereabouts() }
        let n = Double((now.h / 2) * (now.w / 2))
        return Whereabouts(x: sumX / light, y: sumY / light, reach: reach, light: light / n)
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

        show(CompanionStageView(stage: stage, size: size), size: size)
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

    /// The reported fault, filmed frame by frame.
    ///
    /// "After the lighting animation the cigarette disappears for a fraction
    /// of a second, and zooms in from background next to me." A fraction of
    /// a second is invisible to a test that photographs the beginning and
    /// the end, which is how the old ones passed while the thing was plainly
    /// broken. So this follows one person across the whole walk and asks two
    /// questions of every frame: are they there, and where are they.
    ///
    /// At about four frames a second it cannot prove the motion is smooth.
    /// What it can prove is that there is motion at all: that the journey
    /// has a middle. Somebody walking over is caught part of the way there,
    /// part grown, part of the way back out - and a view handing over to a
    /// different view has none of those frames, because there is nothing
    /// between its last position and the next view's first one.
    func testTheWalkOverNeverBlinks() async throws {

        let journey = Journey()
        let size = CGSize(width: 402, height: 874)

        // The journey is stretched for the film, and only for the film.
        //
        // Its phases are tenths of a second. Rendering one frame costs
        // whatever the machine costs, so on a slow one a frame lands before
        // a phase and the next one after it, and a walk nobody caught in
        // the middle reads exactly like the teleport this test exists to
        // catch. That is the whole of why this used to fail about half the
        // time on the CI runner and never locally. Stretching decides how
        // many frames fall inside the walk; it does not change what the
        // walk does, which is still the app's own phases and curves.
        let pace = 3.0
        VisitorCigaretteView.pace = pace

        show(JourneyStageView(journey: journey, size: size), size: size)
        try await settle(0.3)

        // Your own cigarette, alone. Everything after this is measured
        // against it, so what is being measured is the visitor.
        let alone = try frame("walk-00-alone")

        var theirs = CigDesign()
        theirs.title = "Quiet Sparrow"
        theirs.body = Color(red: 0.93, green: 0.94, blue: 0.96)
        theirs.filter = Color(red: 0.88, green: 0.82, blue: 0.62)
        theirs.glow = Color(red: 1, green: 0.38, blue: 0.06)
        theirs.background = Color(red: 0.26, green: 0.52, blue: 0.86)

        let ask = BreakAsk.opening(uid: "a-stranger", design: theirs)
        var companion = Companion(lit: ask, at: .now)
        companion.side = .right

        let beats = Beats()

        // Over on the right and well up the screen, so that coming in to
        // your tip and going back out again are three different places
        // rather than three numbers within noise of each other.
        journey.people = [Visitor(
            companion: companion,
            from: CGPoint(x: 0.88, y: 0.26),
            depth: 0.6,
            handoff: Visitor.Handoff(
                theirsCatches: true,
                onContact: { beats.contacted = true },
                onSettled: { beats.settled = true }
            )
        )]

        // Timed rather than assumed, and captured before it is measured:
        // working out where somebody is costs about a second a frame here,
        // which is slower than the journey it is trying to film.
        //
        // Filmed until they have arrived and finished growing, rather than
        // for a fixed number of frames: a fixed count is a fixed amount of
        // the machine's time, not a fixed amount of the journey, and on a
        // slow machine it ran out partway over. The cap only keeps a
        // journey that never ends from filming for ever - that fails on the
        // assertions below instead.
        let began = Date.now
        var shots: [(at: Double, image: UIImage)] = []
        var arrived: Date?
        while shots.count < 200 {
            shots.append((Date.now.timeIntervalSince(began), try frame()))
            if beats.settled, arrived == nil { arrived = .now }
            if let arrived = arrived,
               Date.now.timeIntervalSince(arrived) > 1.3 * pace { break }
            try await settle(0.02)
        }

        var film: [Whereabouts] = shots.map { shot in
            var where_ = whereabouts(shot.image, without: alone)
            where_.at = shot.at
            return where_
        }
        film.sort { $0.at < $1.at }

        for shot in film {
            print(String(format: "  %.2fs  x%.3f y%.3f  reach %.3f  %.4f",
                         shot.at, shot.x, shot.y, shot.reach, shot.light))
        }

        XCTAssertTrue(beats.contacted, "the tips never touched")
        XCTAssertTrue(beats.settled, "they never straightened up")

        // Not a threshold on how bright they are - a threshold on whether
        // they exist. A view swapped for another one reads as zero here, and
        // zero at any point in the walk is the bug that was reported.
        let dimmest = film.map(\.light).min() ?? 0
        print(String(format: "  dimmest %.4f", dimmest))
        XCTAssertGreaterThan(dimmest, 0.0004,
                             "they went missing partway over - something is still being swapped")

        // The shape of the journey.
        //
        // Not the centroid: leaning in tips them 38 degrees about their own
        // lit end, so the tip is on your cigarette while the body trails
        // away out on their side, and the middle of them barely moves. What
        // moves is the end that matters, so this follows how far across they
        // reach rather than where their average pixel is.
        let first = film.first!, last = film.last!
        let nearest = film.min(by: { $0.reach < $1.reach })!

        print(String(format: "  set off x%.3f y%.3f, reached in to %.3f at %.2fs, stands at x%.3f y%.3f",
                     first.x, first.y, nearest.reach, nearest.at, last.x, last.y))

        XCTAssertGreaterThan(first.x, 0.78, "they did not set off from the courtyard")
        XCTAssertLessThan(nearest.reach, 0.55, "they never reached your cigarette")
        XCTAssertGreaterThan(last.reach, 0.60, "they ended up overlapping your own cigarette")
        XCTAssertGreaterThan(nearest.at, 0, "nothing was filmed")
        XCTAssertLessThan(nearest.at, last.at, "they never came back out again")

        // Out there they are small and dim; here they are a cigarette the
        // size of your own. Both ends of that have to be true, or they
        // arrived without ever having been out there.
        XCTAssertLessThan(first.light * 3, last.light, "they never grew as they came over")

        // And they come down from the back of the courtyard to your own
        // height, because standing beside somebody is the point of going.
        XCTAssertLessThan(first.y + 0.05, last.y, "they stayed up at the back")

        // The middle of the journey, which is the whole question.
        //
        // Coming in, how far they reach across says where they are. Going
        // back out it does not - what reaches furthest then is the pool of
        // light at the meeting point, and that is going out - so the way
        // back is measured by how much of them there is, growing from a
        // cigarette at the back of the courtyard to one the size of yours.
        let span = first.reach - nearest.reach
        let walkingIn = film.filter {
            $0.at < nearest.at
                && $0.reach < first.reach - span * 0.15
                && $0.reach > nearest.reach + span * 0.15
        }

        // A wider band than the way in, because the way back is `easeOut`:
        // most of the growing happens in the first part of it, so a band
        // measured in brightness is crossed quicker than one measured in
        // time, and a narrow one came down to a single frame on a slow
        // machine. Still the middle of the return, not either end of it.
        let grew = last.light - nearest.light
        let steppingBack = film.filter {
            $0.at > nearest.at
                && $0.light > nearest.light + grew * 0.1
                && $0.light < last.light - grew * 0.1
        }

        print("  caught part way in: \(walkingIn.count), part way back out: \(steppingBack.count)")

        // Whether the film could answer the question at all, asked before
        // the question itself. A machine too slow to photograph the walk
        // used to fail as though the walk had never happened, which sent
        // two sessions looking for a bug in the view. If this one fails,
        // raise `pace` rather than lowering the two counts below.
        let duringWalkIn = film.filter { $0.at > first.at && $0.at < nearest.at }.count
        print(String(format: "  %d frames over %.2fs, %d of them during the walk in, pace %.0fx",
                     film.count, last.at, duringWalkIn, pace))
        XCTAssertGreaterThanOrEqual(duringWalkIn, 4,
                                    "the film is too sparse to tell a walk from a jump")

        XCTAssertGreaterThanOrEqual(walkingIn.count, 2,
                                    "they reached your cigarette without crossing the gap")
        XCTAssertGreaterThanOrEqual(steppingBack.count, 1,
                                    "they appeared beside you rather than moving there")

        // The three frames worth looking at, now that there is something to
        // choose them by.
        if let i = film.firstIndex(where: { $0.at == nearest.at }) {
            try save(shots[i].image, "walk-leaning")
        }
        try save(shots[0].image, "walk-away")
        try save(shots[shots.count - 1].image, "walk-standing")
    }

    /// Both sides of you taken, and a third person asks for a light.
    ///
    /// Reported as "the view breaks and they seem to appear next to me", and
    /// it did: the view walked them to a resting place beside you while the
    /// repository quietly declined to put them there, so they arrived on top
    /// of whoever was already standing on that side - two cigarettes and two
    /// names in one place - and then vanished. The light is still theirs to
    /// have. The place beside you is not, so they take it and go.
    func testWithNoRoomLeftTheyTakeTheLightAndGo() async throws {

        let journey = Journey()
        let size = CGSize(width: 402, height: 874)

        show(JourneyStageView(journey: journey, size: size), size: size)
        try await settle(0.3)

        let alone = try frame("noroom-alone")

        var theirs = CigDesign()
        theirs.title = "Quiet Sparrow"
        theirs.body = Color(red: 0.93, green: 0.94, blue: 0.96)
        theirs.filter = Color(red: 0.88, green: 0.82, blue: 0.62)
        theirs.glow = Color(red: 1, green: 0.38, blue: 0.06)
        theirs.background = Color(red: 0.26, green: 0.52, blue: 0.86)

        let ask = BreakAsk.opening(uid: "a-stranger", design: theirs)
        var companion = Companion(lit: ask, at: .now)
        companion.side = .right

        let beats = Beats()
        let home = CGPoint(x: 0.84, y: 0.24)

        journey.people = [Visitor(
            companion: companion,
            from: CGPoint(x: 0.965, y: 0.3),
            depth: 0.5,
            handoff: Visitor.Handoff(
                theirsCatches: true,
                onContact: { beats.contacted = true },
                onSettled: { beats.settled = true }
            ),
            goes: .backOutside(home)
        )]

        let began = Date.now
        var shots: [(at: Double, image: UIImage)] = []
        for _ in 1...40 {
            shots.append((Date.now.timeIntervalSince(began), try frame()))
            try await settle(0.05)
        }

        var film: [Whereabouts] = shots.map { shot in
            var where_ = whereabouts(shot.image, without: alone)
            where_.at = shot.at
            return where_
        }
        film.sort { $0.at < $1.at }

        for shot in film {
            print(String(format: "  %.2fs  x%.3f y%.3f  reach %.3f  %.4f",
                         shot.at, shot.x, shot.y, shot.reach, shot.light))
        }

        XCTAssertTrue(beats.contacted, "the tips never touched - they got nothing out of it")
        XCTAssertTrue(beats.settled, "the handoff never finished, so the offer never cleared")

        let brightest = film.max(by: { $0.light < $1.light })!
        let last = film.last!
        print(String(format: "  came to %.4f, left at %.4f", brightest.light, last.light))

        XCTAssertGreaterThan(brightest.light, 0.004, "they never came over for the light")
        XCTAssertLessThan(last.light, brightest.light * 0.2,
                          "they stayed, with nowhere to stand")

        // And they were never a full-height cigarette beside you on the way
        // out, which is what standing there looks like from here.
        let beside = film.filter { $0.light > 0.05 }
        XCTAssertTrue(beside.isEmpty, "they took a place beside you that was not theirs")
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

    var body: some View {

        let height = size.height * 0.7
        let width = size.width * 0.2
        var mine = CigDesign()
        let _ = { mine.title = "Sunlit Parchment" }()

        return DistantCigaretteView(design: mine, progress: 0.3, height: height)
            .frame(width: width, height: height)
            .overlay {
                BesideYouView(
                    people: stage.company.companions.map { companion in
                        let spot = Courtyard.position(for: companion.name)
                        return Visitor(companion: companion,
                                       from: CGPoint(x: spot.x, y: spot.y),
                                       depth: spot.depth,
                                       handoff: nil)
                    },
                    mine: mine,
                    height: height,
                    yourProgress: 0.3,
                    courtyard: size
                )
            }
            .frame(width: size.width, height: size.height)
            .coordinateSpace(name: Courtyard.space)
    }
}

/// A list of visitors the harness can change while the view is on screen,
/// handoff and all. The one thing `Stage` cannot do: a companion standing
/// there is the end of the journey, and the journey is what broke.
@MainActor
final class Journey: ObservableObject {
    @Published var people: [Visitor] = []
}

/// ContentView's cigarette frame, with whoever is walking over.
struct JourneyStageView: View {

    @ObservedObject var journey: Journey
    let size: CGSize

    var body: some View {

        let height = size.height * 0.7
        let width = size.width * 0.2
        var mine = CigDesign()
        let _ = { mine.title = "Sunlit Parchment" }()

        return DistantCigaretteView(design: mine, progress: 0.3, height: height)
            .frame(width: width, height: height)
            .overlay {
                BesideYouView(
                    people: journey.people,
                    mine: mine,
                    height: height,
                    yourProgress: 0.3,
                    courtyard: size
                )
            }
            .frame(width: size.width, height: size.height)
            .coordinateSpace(name: Courtyard.space)
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
                BesideYouView(
                    people: presence.company.companions.map { companion in
                        let spot = Courtyard.position(for: companion.name)
                        return Visitor(companion: companion,
                                       from: CGPoint(x: spot.x, y: spot.y),
                                       depth: spot.depth,
                                       handoff: nil)
                    },
                    mine: mine,
                    height: height,
                    yourProgress: 0.3,
                    courtyard: size
                )
            }
            .frame(width: size.width, height: size.height)
            .coordinateSpace(name: Courtyard.space)
    }
}

/// One frame of the film: where the visitor was, how much of them there was,
/// and how far across the screen their lit end reached.
struct Whereabouts {
    var x: Double = 0
    var y: Double = 0
    var reach: Double = 0
    var light: Double = 0
    var at: Double = 0
}

/// Whether the two moments in a handoff actually happened. A box, because
/// the callbacks that set them outlive the line that made them.
final class Beats {
    var contacted = false
    var settled = false
}
