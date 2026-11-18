//
//  WaitTests.swift
//  NSSBTests
//

// The wait document itself: what it says when it is created, when it stops
// being joinable, and what survives a round trip through Firestore's encoder.

import XCTest
@testable import NSSB

final class WaitTests: XCTestCase {
    
    override func tearDown() {
        BreakWait.window = 30
    }
    
    // MARK: Opening one
    
    func testAWaitOpensUnpaired() {
        
        let wait = BreakWait.opening(uid: "me", design: design())
        
        XCTAssertFalse(wait.paired)
        XCTAssertNil(wait.partnerName)
        XCTAssertNil(wait.litAt, "nothing is lit until somebody joins")
        XCTAssertEqual(wait.name, "Charcoal Gull")
    }
    
    func testTheWaitIsThirtySeconds() {
        
        let now = Date.now
        let wait = BreakWait.opening(at: now, uid: "me", design: design())
        
        XCTAssertEqual(wait.expiresAt.timeIntervalSince(now), 30, accuracy: 0.001)
    }
    
    /// The rules verify this hash, so it has to be the same function on both
    /// sides. It is also per-wait, so two waits by one person cannot be
    /// linked by anybody reading the collection.
    func testOwnershipIsProvedWithoutStoringAUid() {
        
        let wait = BreakWait.opening(id: "wait-1", uid: "me", design: design())
        
        XCTAssertEqual(wait.waiterHash, BreakOwner.hash(uid: "me", breakId: "wait-1"))
        
        let other = BreakWait.opening(id: "wait-2", uid: "me", design: design())
        XCTAssertNotEqual(other.waiterHash, wait.waiterHash, "two waits must not be linkable")
    }
    
    func testTheCountryCanBeWithheld() {
        
        let shared = BreakWait.opening(uid: "me", design: design(), shareCountry: true)
        let withheld = BreakWait.opening(uid: "me", design: design(), shareCountry: false)
        
        XCTAssertNil(withheld.country)
        XCTAssertEqual(shared.country, Locale.current.region?.identifier)
    }
    
    // MARK: Whether the chair is free
    
    func testAFreshWaitIsOpen() {
        let wait = BreakWait.opening(uid: "me", design: design())
        XCTAssertTrue(wait.isOpen())
    }
    
    func testAnExpiredWaitIsNotOpen() {
        
        let now = Date.now
        let wait = BreakWait.opening(at: now.addingTimeInterval(-31), uid: "me", design: design())
        
        XCTAssertFalse(wait.isOpen(at: now), "thirty seconds is thirty seconds")
    }
    
    func testAPairedWaitIsNotOpen() {
        
        var wait = BreakWait.opening(uid: "me", design: design())
        wait.paired = true
        
        XCTAssertFalse(wait.isOpen(), "the chair is taken, even though time is left")
    }
    
    func testProgressRunsFromZeroToOneAndStops() {
        
        let now = Date.now
        let wait = BreakWait.opening(at: now, uid: "me", design: design())
        
        XCTAssertEqual(wait.progress(at: now), 0, accuracy: 0.001)
        XCTAssertEqual(wait.progress(at: now.addingTimeInterval(15)), 0.5, accuracy: 0.001)
        XCTAssertEqual(wait.progress(at: now.addingTimeInterval(30)), 1, accuracy: 0.001)
        XCTAssertEqual(wait.progress(at: now.addingTimeInterval(90)), 1, accuracy: 0.001,
                       "clamped, so a late snapshot cannot drive a fade past its end")
    }
    
    // MARK: The companion, from both sides
    
    func testTheWaiterLearnsWhoJoinedThem() throws {
        
        var wait = BreakWait.opening(uid: "me", design: design())
        wait.paired = true
        wait.partnerName = "Paper Kestrel"
        wait.partnerDesign = design(title: "Paper Kestrel")
        wait.partnerCountry = "JP"
        wait.partnerTzOffset = 32400
        wait.litAt = Date(timeIntervalSince1970: 1_000_000)

        let companion = try XCTUnwrap(Companion(partnerOf: wait))

        XCTAssertEqual(companion.name, "Paper Kestrel")
        XCTAssertEqual(companion.country, "JP")
        XCTAssertEqual(companion.tzOffset, 32400)

        // Their cigarette starts at the instant you both lit, which is the
        // whole of layer 3: the two burn from one second and end on one.
        XCTAssertEqual(companion.startedAt, Date(timeIntervalSince1970: 1_000_000))
    }

    /// A pairing with no ignition instant cannot say when their cigarette
    /// was lit, so it cannot be drawn. The rules require litAt on every
    /// pairing, so this is a corrupt document rather than a person.
    func testAPairingWithNoInstantIsNotACompanion() {

        var wait = BreakWait.opening(uid: "me", design: design())
        wait.paired = true
        wait.partnerName = "Paper Kestrel"

        XCTAssertNil(Companion(partnerOf: wait))
    }
    
    func testThereIsNoCompanionUntilSomebodyJoins() {
        
        let wait = BreakWait.opening(uid: "me", design: design())
        
        XCTAssertNil(Companion(partnerOf: wait))
    }
    
    /// A paired document with no name in it is a bug, not a person who
    /// declined to be named - and it must not become a nameless cigarette
    /// standing next to yours for five minutes.
    func testAnEmptyPartnerNameIsNotACompanion() {
        
        var wait = BreakWait.opening(uid: "me", design: design())
        wait.paired = true
        wait.partnerName = ""
        
        XCTAssertNil(Companion(partnerOf: wait))
    }
    
    func testTheJoinerSeesTheWaiter() {
        
        let wait = BreakWait.opening(uid: "them", design: design(title: "Paper Kestrel"))
        let companion = Companion(waiter: wait, litAt: .now)
        
        XCTAssertEqual(companion.name, "Paper Kestrel")
        XCTAssertEqual(companion.design.title, "Paper Kestrel")
        XCTAssertEqual(companion.tzOffset, wait.tzOffset)
    }
    
    // MARK: What the state says
    
    func testTheStateKnowsWhatItIs() {
        
        let wait = BreakWait.opening(uid: "me", design: design())
        let companion = Companion(waiter: wait, litAt: .now)
        let litAt = Date(timeIntervalSince1970: 1_000_000)
        
        XCTAssertTrue(CompanyState.waiting(wait).isWaiting)
        XCTAssertFalse(CompanyState.idle.isWaiting)
        XCTAssertEqual(CompanyState.waiting(wait).openWait, wait)
        XCTAssertNil(CompanyState.alone.openWait)
        
        let together = CompanyState.together([companion], since: litAt)
        XCTAssertEqual(together.companions, [companion])
        XCTAssertEqual(together.litAt, litAt)
        XCTAssertFalse(together.isWaiting)
        XCTAssertFalse(together.isFull, "one person is not both sides of you")
        XCTAssertNil(together.openWait, "you are not waiting once somebody came")
        XCTAssertTrue(CompanyState.idle.companions.isEmpty)
        XCTAssertNil(CompanyState.idle.litAt)
    }
    
    // MARK: The wire
    
    /// The shared instant is the one field both devices depend on, so it has
    /// to survive the trip exactly.
    func testAWaitSurvivesEncodingAndDecoding() throws {
        
        var wait = BreakWait.opening(
            at: Date(timeIntervalSince1970: 1_000_000),
            id: "wait-1",
            uid: "me",
            design: design()
        )
        wait.paired = true
        wait.partnerName = "Paper Kestrel"
        wait.partnerDesign = design(title: "Paper Kestrel")
        wait.partnerCountry = "PT"
        wait.partnerTzOffset = 3600
        wait.litAt = Date(timeIntervalSince1970: 1_000_020)
        
        let data = try JSONEncoder().encode(wait)
        let back = try JSONDecoder().decode(BreakWait.self, from: data)
        
        // Field by field rather than whole-struct, for the same reason
        // PresenceTests does it: a colour's components do not survive the
        // trip to the last bit, and that is neither news nor a problem.
        XCTAssertEqual(back.id, wait.id)
        XCTAssertEqual(back.waiterHash, wait.waiterHash)
        XCTAssertEqual(back.name, wait.name)
        XCTAssertEqual(back.country, wait.country)
        XCTAssertEqual(back.tzOffset, wait.tzOffset)
        XCTAssertTrue(back.paired)
        XCTAssertEqual(back.partnerName, wait.partnerName)
        XCTAssertEqual(back.partnerCountry, wait.partnerCountry)
        XCTAssertEqual(back.partnerTzOffset, wait.partnerTzOffset)
        XCTAssertEqual(back.design.title, wait.design.title)
        XCTAssertEqual(back.partnerDesign?.title, wait.partnerDesign?.title)
        XCTAssertEqual(back.createdAt.timeIntervalSince1970,
                       wait.createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(back.expiresAt.timeIntervalSince1970,
                       wait.expiresAt.timeIntervalSince1970, accuracy: 0.001)
        
        // The one field both devices depend on, so it is checked on its own.
        let litAt = try XCTUnwrap(back.litAt)
        let original = try XCTUnwrap(wait.litAt)
        XCTAssertEqual(litAt.timeIntervalSince1970,
                       original.timeIntervalSince1970, accuracy: 0.001)
    }
    
    private func design(title: String = "Charcoal Gull") -> CigDesign {
        var design = CigDesign()
        design.title = title
        return design
    }
}
