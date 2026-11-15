//
//  PresenceTests.swift
//  NSSBTests
//

// A presence document is what strangers see. These cover the arithmetic that
// decides where a cigarette sits in the courtyard and what time it says it is
// where they are.

import XCTest
import SwiftUI
@testable import NSSB

final class PresenceTests: XCTestCase {
    
    private func presence(startedAt: Date, tzOffset: Int = 0, name: String = "Hollow Lantern") -> BreakPresence {
        BreakPresence(
            id: "test",
            ownerHash: BreakOwner.hash(uid: "uid", breakId: "test"),
            startedAt: startedAt,
            endsAt: startedAt.addingTimeInterval(Date.breakLength),
            name: name,
            country: "DK",
            tzOffset: tzOffset,
            design: CigDesign()
        )
    }
    
    // MARK: Burn position
    
    func testProgressRunsFromZeroToOneAcrossTheBreak() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let p = presence(startedAt: start)
        
        XCTAssertEqual(p.progress(at: start), 0, accuracy: 0.001)
        XCTAssertEqual(p.progress(at: start.addingTimeInterval(Date.breakLength / 2)), 0.5, accuracy: 0.001)
        XCTAssertEqual(p.progress(at: start.addingTimeInterval(Date.breakLength)), 1, accuracy: 0.001)
    }
    
    func testProgressIsClampedOutsideTheBreak() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let p = presence(startedAt: start)
        
        XCTAssertEqual(p.progress(at: start.addingTimeInterval(-60)), 0, "cannot be less lit than unlit")
        XCTAssertEqual(p.progress(at: start.addingTimeInterval(9_999)), 1, "cannot burn past the filter")
    }
    
    func testIsLiveFlipsExactlyAtEndsAt() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let p = presence(startedAt: start)
        
        XCTAssertTrue(p.isLive(at: start))
        XCTAssertTrue(p.isLive(at: p.endsAt.addingTimeInterval(-0.5)))
        XCTAssertFalse(p.isLive(at: p.endsAt), "a finished break is not live")
        XCTAssertFalse(p.isLive(at: p.endsAt.addingTimeInterval(1)))
    }
    
    // MARK: "06:41 there"
    
    func testLocalTimeUsesTheirOffsetNotOurs() {
        // 12:00 UTC on some arbitrary day
        let dayStart: Int = 1_700_000_000 - (1_700_000_000 % 86_400)
        let noonUTC = Date(timeIntervalSince1970: TimeInterval(dayStart + 43_200))
        
        XCTAssertEqual(presence(startedAt: noonUTC, tzOffset: 0).localTimeString(at: noonUTC), "12:00")
        XCTAssertEqual(presence(startedAt: noonUTC, tzOffset: 3600).localTimeString(at: noonUTC), "13:00")
        XCTAssertEqual(presence(startedAt: noonUTC, tzOffset: 9 * 3600).localTimeString(at: noonUTC), "21:00")
        XCTAssertEqual(presence(startedAt: noonUTC, tzOffset: -3 * 3600).localTimeString(at: noonUTC), "09:00")
    }
    
    func testLocalTimeIsAlwaysZeroPaddedFiveCharacters() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        for offset in stride(from: -12 * 3600, through: 14 * 3600, by: 1800) {
            let s = presence(startedAt: t, tzOffset: offset).localTimeString(at: t)
            XCTAssertEqual(s.count, 5, "\(s) is not HH:mm")
            XCTAssertEqual(s[s.index(s.startIndex, offsetBy: 2)], ":")
        }
    }
    
    // MARK: Building one
    
    func testStartingDerivesEndsAtFromTheBreakLength() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let p = BreakPresence.starting(at: start, uid: "uid", design: CigDesign(title: "Hollow Lantern"))
        
        XCTAssertEqual(p.startedAt, start)
        XCTAssertEqual(p.endsAt.timeIntervalSince(start), Date.breakLength, accuracy: 0.001)
        XCTAssertEqual(p.name, "Hollow Lantern", "the name comes from the design")
    }
    
    func testStartingReusesAGivenIdSoARepublishIsNotADuplicate() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let first = BreakPresence.starting(at: start, uid: "uid", design: CigDesign())
        let republished = BreakPresence.starting(at: start, id: first.id, uid: "uid", design: CigDesign())
        
        XCTAssertEqual(first.id, republished.id)
        XCTAssertEqual(first.endsAt, republished.endsAt, "a republish must not extend the break")
    }
    
    func testFreshBreaksGetDistinctIds() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let ids = (0..<50).map { _ in BreakPresence.starting(at: start, uid: "uid", design: CigDesign()).id }
        XCTAssertEqual(Set(ids).count, ids.count, "two breaks shared an id")
    }
    
    func testCountryCanBeWithheld() {
        let p = BreakPresence.starting(at: .now, uid: "uid", design: CigDesign(), shareCountry: false)
        XCTAssertNil(p.country, "there are places where a flag is not a neutral act")
    }
    
    // MARK: Ownership

    /// The whole point of the hash: it proves ownership to the rules without
    /// letting anyone link two breaks by the same person.
    func testOwnerHashDiffersPerBreakForTheSameUser() {
        let a = BreakOwner.hash(uid: "same-user", breakId: "break-1")
        let b = BreakOwner.hash(uid: "same-user", breakId: "break-2")
        XCTAssertNotEqual(a, b, "two breaks by one person are linkable")
    }

    func testOwnerHashIsStableForTheSameBreak() {
        // A republish after a kill has to produce the same hash or the rules
        // reject the update.
        XCTAssertEqual(BreakOwner.hash(uid: "u", breakId: "b"),
                       BreakOwner.hash(uid: "u", breakId: "b"))
    }

    func testOwnerHashDiffersBetweenUsersForTheSameBreakId() {
        XCTAssertNotEqual(BreakOwner.hash(uid: "user-a", breakId: "b"),
                          BreakOwner.hash(uid: "user-b", breakId: "b"))
    }

    func testNoUidIsStoredOnThePresenceDocument() throws {
        let p = BreakPresence.starting(at: .now, uid: "secret-uid", design: CigDesign())
        let json = String(data: try JSONEncoder().encode(p), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("secret-uid"), "the uid leaked into the document")
    }

    // MARK: Round trip
    
    func testPresenceSurvivesEncodingAndDecoding() throws {
        let original = BreakPresence.starting(
            at: Date(timeIntervalSince1970: 1_000_000),
            uid: "uid",
            design: CigDesign(title: "Hollow Lantern",
                              glow: Color(red: 1, green: 0.2, blue: 0))
        )
        
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(BreakPresence.self, from: data)
        
        XCTAssertEqual(original.id, back.id)
        XCTAssertEqual(original.ownerHash, back.ownerHash)
        XCTAssertEqual(original.name, back.name)
        XCTAssertEqual(original.country, back.country)
        XCTAssertEqual(original.tzOffset, back.tzOffset)
        XCTAssertEqual(original.startedAt.timeIntervalSince1970,
                       back.startedAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(original.endsAt.timeIntervalSince1970,
                       back.endsAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(original.design.title, back.design.title)
    }
}
