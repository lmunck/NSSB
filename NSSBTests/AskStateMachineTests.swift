//
//  AskStateMachineTests.swift
//  NSSBTests
//

// The ask, driven end to end with no network: idle -> asking -> lit(by:) ->
// done on one side, and idle -> an offer you can answer on the other.
//
// SimulatedPresenceService is the backend here, and it deliberately never
// answers an ask by itself - so every answer in this file is written by the
// test standing in for the other device, which is also the only honest way
// to test a gift.

import XCTest
@testable import NSSB

@MainActor
final class AskStateMachineTests: XCTestCase {

    private var service: SimulatedPresenceService!
    private var repository: PresenceRepository!

    override func setUp() async throws {

        // The repository remembers a break across launches in UserDefaults,
        // which in a test target is shared between tests.
        UserDefaults.standard.removeObject(forKey: "presence.liveBreakId")
        UserDefaults.standard.removeObject(forKey: "presence.liveBreakStart")

        service = SimulatedPresenceService()
        repository = PresenceRepository(service: service)
        await repository.start()
    }

    override func tearDown() async throws {
        BreakAsk.window = 8
        service = nil
        repository = nil
    }

    // MARK: - Asking

    func testItStartsIdle() {
        XCTAssertEqual(repository.ask, .idle)
    }

    func testAskingPutsAnAskOutThere() async throws {

        await repository.askForALight(design: design())

        let ask = try XCTUnwrap(repository.ask.openAsk)

        XCTAssertTrue(repository.ask.isAsking)
        XCTAssertEqual(ask.name, "Charcoal Gull")
        XCTAssertFalse(ask.claimed)
        XCTAssertEqual(service.askIds, [ask.id], "the ask should be the one document out there")
    }

    /// The rules reject an empty name outright, and a silent rejection would
    /// look exactly like nobody answering.
    func testAnUnnamedCigaretteStillGetsARolledName() async throws {

        await repository.askForALight(design: design(title: ""))

        let ask = try XCTUnwrap(repository.ask.openAsk)
        XCTAssertFalse(ask.name.isEmpty)
    }

    func testAskingTwiceDoesNotOpenASecondAsk() async throws {

        await repository.askForALight(design: design())
        let first = try XCTUnwrap(repository.ask.openAsk)

        await repository.askForALight(design: design())

        XCTAssertEqual(repository.ask.openAsk?.id, first.id)
        XCTAssertEqual(service.askIds.count, 1)
    }

    /// The cigarette going out has to end the ask with it, whatever the ask
    /// was doing.
    ///
    /// It only ever cleared a finished one, so an ask caught mid-handoff -
    /// by the break being cancelled, or by the watch overwriting it - stayed
    /// `.lit` for good. The row went on saying somebody was giving you a
    /// light, and `reachOut` refused to start because by its reading one was
    /// already in flight.
    func testTheCigaretteGoingOutMidHandoffLetsYouAskAgain() async throws {

        await repository.askForALight(design: design())
        let ask = try XCTUnwrap(repository.ask.openAsk)
        try await answer(ask, as: "Hollow Lantern", progress: 0.4)

        try await waitUntil("the light to arrive") {
            if case .lit = self.repository.ask { return true }
            return false
        }

        await repository.breakEnded()

        guard case .idle = repository.ask else {
            return XCTFail("the ask outlived the cigarette: \(repository.ask)")
        }

        await repository.reachOut(design: design())

        XCTAssertNotNil(repository.ask.openAsk, "could not ask anybody for a light afterwards")
        XCTAssertNotNil(repository.company.openWait, "could not wait for anybody afterwards")
    }

    // MARK: Being answered

    func testSomebodyAnsweringLightsYou() async throws {

        await repository.askForALight(design: design())
        let ask = try XCTUnwrap(repository.ask.openAsk)

        try await answer(ask, as: "Hollow Lantern", progress: 0.77)

        try await waitUntil("the light to arrive") {
            if case .lit = self.repository.ask { return true }
            return false
        }

        guard case .lit(let giver) = repository.ask else {
            return XCTFail("expected to be lit, got \(repository.ask)")
        }

        XCTAssertEqual(giver.name, "Hollow Lantern")
        XCTAssertEqual(giver.progress, 0.77, "their burn position is the point of storing it")
    }

    /// Answered means finished. An ask that has been granted must not be left
    /// standing in anyone's courtyard, and nothing is left behind.
    func testAnAnsweredAskIsTakenDown() async throws {

        await repository.askForALight(design: design())
        let ask = try XCTUnwrap(repository.ask.openAsk)

        try await answer(ask, as: "Hollow Lantern", progress: 0.2)

        try await waitUntil("the ask to be removed") { self.service.askIds.isEmpty }
    }

    func testTheHandoffEndsInDoneWithWhoGaveIt() async throws {

        await repository.askForALight(design: design())
        let ask = try XCTUnwrap(repository.ask.openAsk)
        try await answer(ask, as: "Hollow Lantern", progress: 0.4)

        try await waitUntil("the light to arrive") {
            if case .lit = self.repository.ask { return true }
            return false
        }

        repository.handoffFinished()

        guard case .done(let giver) = repository.ask else {
            return XCTFail("expected to be done, got \(repository.ask)")
        }
        XCTAssertEqual(giver?.name, "Hollow Lantern")
    }

    // MARK: Nobody answering

    func testEightSecondsOfSilenceLightsYourOwn() async throws {

        BreakAsk.window = 0.3

        await repository.askForALight(design: design())
        XCTAssertTrue(repository.ask.isAsking)

        // Both, because the state flips before the document is withdrawn -
        // and an unanswered ask must not be left hanging either.
        try await waitUntil("the ask to time out and be taken down") {
            self.repository.ask == .done(givenBy: nil) && self.service.askIds.isEmpty
        }
    }

    /// A light that arrives at 7.9 seconds is still a light.
    func testALightThatArrivesLateIsNotThrownAway() async throws {

        BreakAsk.window = 0.4

        await repository.askForALight(design: design())
        let ask = try XCTUnwrap(repository.ask.openAsk)

        try await Task.sleep(nanoseconds: 250_000_000)
        try await answer(ask, as: "Hollow Lantern", progress: 0.5)

        try await waitUntil("the light to arrive") {
            if case .lit = self.repository.ask { return true }
            return false
        }

        // And the timeout that was armed must not fire afterwards and
        // overwrite it with "nobody came".
        try await Task.sleep(nanoseconds: 400_000_000)

        if case .lit = repository.ask {} else {
            XCTFail("the timeout stole a light that had already arrived: \(repository.ask)")
        }
    }

    // MARK: Taking the question back

    func testLightingYourOwnWhileAskingTakesTheAskDown() async throws {

        await repository.askForALight(design: design())
        XCTAssertFalse(service.askIds.isEmpty)

        await repository.breakStarted(at: .now, design: design())

        XCTAssertEqual(repository.ask, .idle)
        XCTAssertTrue(service.askIds.isEmpty, "a cigarette asking for a light it no longer needs is a small lie")
    }

    func testCancellingAnAskReturnsToIdle() async throws {

        await repository.askForALight(design: design())
        await repository.cancelAsk()

        XCTAssertEqual(repository.ask, .idle)
        XCTAssertTrue(service.askIds.isEmpty)
    }

    func testClearingOnlyEverWorksOnAFinishedAsk() async throws {

        await repository.askForALight(design: design())

        repository.clearAsk()

        XCTAssertTrue(repository.ask.isAsking, "clearing must never be able to cut an ask short")
    }

    // MARK: - The other side

    func testALitSmokerSeesAnOpenAsk() async throws {

        let theirs = try await strangerAsks()
        await repository.breakStarted(at: .now, design: design())

        try await waitUntil("the offer to appear") {
            self.repository.offers.contains { $0.id == theirs.id }
        }
    }

    func testAnUnlitSmokerHasNothingToGive() async throws {

        let theirs = try await strangerAsks()

        await repository.offerLight(to: theirs)

        XCTAssertNil(repository.giving)
        XCTAssertEqual(service.askIds, [theirs.id], "the ask should be untouched")
    }

    func testGivingALightAnswersTheAskWithYourOwnBurnPosition() async throws {

        let theirs = try await strangerAsks()

        let startedAt = Date.now.addingTimeInterval(-Date.breakLength / 2)
        await repository.breakStarted(at: startedAt, design: design(title: "Hollow Lantern"))

        await repository.offerLight(to: theirs)

        XCTAssertEqual(repository.giving?.id, theirs.id)

        // What the asker will read.
        let answered = try await ask(theirs.id)
        XCTAssertTrue(answered.claimed)
        XCTAssertEqual(answered.giverName, "Hollow Lantern")
        XCTAssertEqual(answered.giverProgress ?? 0, 0.5, accuracy: 0.05)

        repository.offerFinished()
        XCTAssertNil(repository.giving)
    }

    /// Two people reach for their lighter at the same moment. The rules let
    /// exactly one claim through; here the other device has already won.
    func testOnlyTheFirstLightCounts() async throws {

        let theirs = try await strangerAsks()
        await repository.breakStarted(at: .now, design: design(title: "Hollow Lantern"))

        try await waitUntil("the offer to appear") {
            self.repository.offers.contains { $0.id == theirs.id }
        }

        // Somebody quicker.
        try await answer(theirs, as: "Paper Heron", progress: 0.1)

        await repository.offerLight(to: theirs)

        XCTAssertNil(repository.giving, "you cannot give a light somebody else already gave")
        XCTAssertFalse(repository.offers.contains { $0.id == theirs.id })

        let answered = try await ask(theirs.id)
        XCTAssertEqual(answered.giverName, "Paper Heron", "the first one wins")
    }

    func testTheOffersGoOutWithYourCigarette() async throws {

        _ = try await strangerAsks()
        await repository.breakStarted(at: .now, design: design())

        try await waitUntil("the offer to appear") { self.repository.offers.isEmpty == false }

        await repository.breakEnded()

        XCTAssertTrue(repository.offers.isEmpty, "an unlit cigarette has nothing to give")
        XCTAssertNil(repository.giving)
    }

    // MARK: - Helpers

    private func design(title: String = "Charcoal Gull") -> CigDesign {
        var design = CigDesign()
        design.title = title
        return design
    }

    /// Somebody else in the courtyard asks for a light.
    private func strangerAsks() async throws -> BreakAsk {
        let theirs = BreakAsk.opening(uid: "a-stranger", design: design(title: "Paper Kestrel"))
        try await service.openAsk(theirs)
        return theirs
    }

    /// The other device answering, which is the only thing that can.
    private func answer(_ ask: BreakAsk, as name: String, progress: Double) async throws {
        try await service.claimAsk(
            id: ask.id,
            giverName: name,
            giverDesign: design(title: name),
            giverProgress: progress,
            giverCountry: "JP",
            giverTzOffset: 32400
        )
    }

    private func ask(_ id: String) async throws -> BreakAsk {
        var found: BreakAsk?
        service.observeOwnAsk(id: id) { found = $0 }
        service.stopObservingOwnAsk()
        return try XCTUnwrap(found, "no ask \(id)")
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
