//
//  AskTests.swift
//  NSSBTests
//

// "Got a light?"
//
// Two halves. The model is pure arithmetic and a hash, and the state machine
// is driven end to end against SimulatedPresenceService - opened, answered,
// timed out, cancelled - with no network and no Firebase project.
//
// What cannot be tested here is the part that makes the race safe: exactly
// one claimed: false -> true transition, enforced by firestore.rules. The
// emulator needs a Java runtime this machine does not have, so that half is
// verified against the live project instead. See DEVELOPMENT.md.

import XCTest
@testable import NSSB

final class AskTests: XCTestCase {

    // MARK: - The document

    func testAnAskIsEightSecondsLong() {
        let at = Date(timeIntervalSince1970: 1_000_000)
        let ask = BreakAsk.opening(at: at, uid: "uid", design: design())

        XCTAssertEqual(ask.createdAt, at)
        XCTAssertEqual(ask.expiresAt.timeIntervalSince(at), 8, accuracy: 0.001)
    }

    func testAnAskIsNotAnsweredWhenItIsWritten() {
        let ask = BreakAsk.opening(uid: "uid", design: design())

        XCTAssertFalse(ask.claimed, "the rules reject an ask that is born answered")
        XCTAssertNil(ask.giverName)
        XCTAssertNil(ask.giverDesign)
        XCTAssertNil(ask.giverProgress)
    }

    /// The hash has to match `hashing.sha256(...).toHexString().lower()` in
    /// firestore.rules exactly. A base64 mismatch here once rejected every
    /// write silently, with a rule that looked correct.
    func testTheAskerHashIsLowercaseHexAndMatchesTheOneSourceOfTruth() {
        let ask = BreakAsk.opening(id: "ask-1", uid: "uid-1", design: design())

        XCTAssertEqual(ask.askerHash, BreakOwner.hash(uid: "uid-1", breakId: "ask-1"))
        XCTAssertEqual(ask.askerHash.count, 64)
        XCTAssertEqual(ask.askerHash, ask.askerHash.lowercased())
        XCTAssertTrue(ask.askerHash.allSatisfy { $0.isHexDigit })
    }

    /// Nothing in the document links two asks by the same person.
    func testTheSameAskerHashesDifferentlyForEveryAsk() {
        let one = BreakAsk.opening(id: "ask-1", uid: "uid-1", design: design())
        let two = BreakAsk.opening(id: "ask-2", uid: "uid-1", design: design())

        XCTAssertNotEqual(one.askerHash, two.askerHash)
    }

    func testAnAskCarriesTheRolledNameAndNeverAnythingTyped() {
        let ask = BreakAsk.opening(uid: "uid", design: design(title: "Charcoal Gull"))

        XCTAssertEqual(ask.name, "Charcoal Gull")
        XCTAssertEqual(ask.name, ask.design.title)
    }

    func testTheFlagIsOptOut() {
        let shared = BreakAsk.opening(uid: "uid", design: design(), shareCountry: true)
        let withheld = BreakAsk.opening(uid: "uid", design: design(), shareCountry: false)

        XCTAssertNil(withheld.country)
        XCTAssertEqual(shared.country, Locale.current.region?.identifier)
    }

    // MARK: Open, answered, expired

    func testAnAskIsOpenUntilItExpires() {
        let at = Date(timeIntervalSince1970: 1_000_000)
        let ask = BreakAsk.opening(at: at, uid: "uid", design: design())

        XCTAssertTrue(ask.isOpen(at: at))
        XCTAssertTrue(ask.isOpen(at: ask.expiresAt.addingTimeInterval(-0.5)))
        XCTAssertFalse(ask.isOpen(at: ask.expiresAt), "eight seconds is eight seconds")
        XCTAssertFalse(ask.isOpen(at: ask.expiresAt.addingTimeInterval(60)))
    }

    func testAnAnsweredAskIsClosedEvenWithTimeLeft() {
        let at = Date(timeIntervalSince1970: 1_000_000)
        var ask = BreakAsk.opening(at: at, uid: "uid", design: design())
        ask.claimed = true

        XCTAssertFalse(ask.isOpen(at: at), "nobody else gets to answer it twice")
    }

    // MARK: The pulse

    func testProgressRunsFromZeroToOneAcrossTheWindow() {
        let at = Date(timeIntervalSince1970: 1_000_000)
        let ask = BreakAsk.opening(at: at, uid: "uid", design: design())

        XCTAssertEqual(ask.progress(at: at), 0, accuracy: 0.001)
        XCTAssertEqual(ask.progress(at: at.addingTimeInterval(4)), 0.5, accuracy: 0.001)
        XCTAssertEqual(ask.progress(at: at.addingTimeInterval(8)), 1, accuracy: 0.001)
    }

    func testProgressIsClampedOutsideTheWindow() {
        let at = Date(timeIntervalSince1970: 1_000_000)
        let ask = BreakAsk.opening(at: at, uid: "uid", design: design())

        XCTAssertEqual(ask.progress(at: at.addingTimeInterval(-10)), 0)
        XCTAssertEqual(ask.progress(at: at.addingTimeInterval(9_999)), 1)
    }

    // MARK: The wire

    /// An ask is a wire format, like CigDesign. The giver's half is written
    /// by a different device than the one that reads it.
    ///
    /// Field by field rather than by comparing the two documents, because
    /// SwiftUI's Color is only ever equal to itself: a decoded colour with
    /// identical channels is a different object, so an == on the whole
    /// document fails while printing two identical lines. CigDesign's own
    /// encoding is covered in CigDesignCodableTests.
    func testAnAnsweredAskSurvivesTheRoundTrip() throws {

        var ask = BreakAsk.opening(uid: "uid", design: design(title: "Charcoal Gull"))
        ask.claimed = true
        ask.giverName = "Hollow Lantern"
        ask.giverDesign = design(title: "Hollow Lantern")
        ask.giverProgress = 0.82

        let data = try JSONEncoder().encode(ask)
        let back = try JSONDecoder().decode(BreakAsk.self, from: data)

        XCTAssertEqual(back.id, ask.id)
        XCTAssertEqual(back.askerHash, ask.askerHash)
        XCTAssertEqual(back.createdAt.timeIntervalSince1970,
                       ask.createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(back.expiresAt.timeIntervalSince1970,
                       ask.expiresAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(back.name, "Charcoal Gull")
        XCTAssertEqual(back.country, ask.country)
        XCTAssertEqual(back.tzOffset, ask.tzOffset)
        XCTAssertTrue(back.claimed)
        XCTAssertEqual(back.giverName, "Hollow Lantern")
        XCTAssertEqual(back.giverProgress, 0.82)
        XCTAssertEqual(back.giverDesign?.title, "Hollow Lantern")
    }

    // MARK: Who gave you the light

    func testThereIsNoGiverUntilSomebodyAnswers() {
        let ask = BreakAsk.opening(uid: "uid", design: design())
        XCTAssertNil(AskGiver(ask))
    }

    func testTheGiverKeepsTheirBurnPosition() throws {

        var ask = BreakAsk.opening(uid: "uid", design: design())
        ask.claimed = true
        ask.giverName = "Hollow Lantern"
        ask.giverDesign = design(title: "Hollow Lantern")
        ask.giverProgress = 0.9

        let giver = try XCTUnwrap(AskGiver(ask))

        XCTAssertEqual(giver.name, "Hollow Lantern")
        XCTAssertEqual(giver.progress, 0.9, "being lit by somebody almost finished should look different")
        XCTAssertEqual(giver.design.title, "Hollow Lantern")
    }

    /// A claim with no name is not a gift from anybody, and the rules reject
    /// it - but a document written by some future client should not be able
    /// to put a nameless stranger on screen either.
    func testAnAnsweredAskWithNoNameIsNotAGiver() {
        var ask = BreakAsk.opening(uid: "uid", design: design())
        ask.claimed = true
        ask.giverName = ""

        XCTAssertNil(AskGiver(ask))
    }

    // MARK: - Helpers

    private func design(title: String = "Charcoal Gull") -> CigDesign {
        var design = CigDesign()
        design.title = title
        return design
    }
}
