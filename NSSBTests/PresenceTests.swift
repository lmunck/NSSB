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
    
    // MARK: Where they are in their own day
    
    /// The clock was replaced by a sun or a moon. A time of day gets read
    /// against your own and, beside a cigarette already counting down, it
    /// looked like a second timer. The hour behind it still has to be theirs.
    func testTheHourUsesTheirOffsetNotOurs() {
        // 12:00 UTC on some arbitrary day
        let dayStart: Int = 1_700_000_000 - (1_700_000_000 % 86_400)
        let noonUTC = Date(timeIntervalSince1970: TimeInterval(dayStart + 43_200))
        
        XCTAssertEqual(presence(startedAt: noonUTC, tzOffset: 0).localHour(at: noonUTC), 12)
        XCTAssertEqual(presence(startedAt: noonUTC, tzOffset: 3600).localHour(at: noonUTC), 13)
        XCTAssertEqual(presence(startedAt: noonUTC, tzOffset: 9 * 3600).localHour(at: noonUTC), 21)
        XCTAssertEqual(presence(startedAt: noonUTC, tzOffset: -3 * 3600).localHour(at: noonUTC), 9)
    }
    
    func testEveryHourHasSomewhereToBeInTheDay() {
        
        var seen: Set<Daylight> = []
        for hour in 0..<24 {
            seen.insert(daylight(atHour: hour))
        }
        
        XCTAssertEqual(seen, [.dawn, .day, .dusk, .night],
                       "some part of the day has no symbol to stand for it")
    }
    
    func testTheDayRunsDawnThroughNight() {
        XCTAssertEqual(daylight(atHour: 3), .night)
        XCTAssertEqual(daylight(atHour: 6), .dawn)
        XCTAssertEqual(daylight(atHour: 12), .day)
        XCTAssertEqual(daylight(atHour: 19), .dusk)
        XCTAssertEqual(daylight(atHour: 23), .night)
    }
    
    /// Moves the clock rather than the offset. A timezone is only valid
    /// within eighteen hours of GMT, so faking a late hour with a huge
    /// offset silently falls back to GMT and tests nothing.
    private func daylight(atHour hour: Int) -> Daylight {
        let dayStart: Int = 1_700_000_000 - (1_700_000_000 % 86_400)
        let t = Date(timeIntervalSince1970: TimeInterval(dayStart + hour * 3600))
        return presence(startedAt: t, tzOffset: 0).daylight(at: t)
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
