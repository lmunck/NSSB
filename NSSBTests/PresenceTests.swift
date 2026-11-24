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
    
    // MARK: What the watch is told
    
    // BreakCompany is a wire format, which puts it in the same bracket as
    // CigDesign: a phone and a watch on different builds have to go on
    // understanding each other, and nothing here can be renamed or retyped.
    // It is also the one payload with no merge behind it - the watch takes
    // the phone's word for who is out here - so the filtering that stands in
    // for a merge is what these cover.
    
    private func beside(_ id: String, startedAt: Date, onLeft: Bool = true) -> BreakCompany.Companion {
        BreakCompany.Companion(
            id: id,
            name: "Hollow Lantern",
            design: CigDesign(title: "Hollow Lantern"),
            startedAt: startedAt,
            onLeft: onLeft
        )
    }
    
    func testACompanionBurnsOnTheirOwnClock() {
        let lit = Date(timeIntervalSince1970: 1_000_000)
        let them = beside("one", startedAt: lit)
        
        XCTAssertEqual(them.progress(at: lit), 0, accuracy: 0.001)
        XCTAssertEqual(them.progress(at: lit.addingTimeInterval(Date.breakLength / 2)), 0.5, accuracy: 0.001)
        XCTAssertEqual(them.progress(at: lit.addingTimeInterval(Date.breakLength)), 1, accuracy: 0.001)
        
        // Clamped at both ends, the way a presence document is: somebody
        // whose payload arrived early is not drawn burning backwards.
        XCTAssertEqual(them.progress(at: lit.addingTimeInterval(-60)), 0, accuracy: 0.001)
        XCTAssertEqual(them.progress(at: lit.addingTimeInterval(Date.breakLength * 3)), 1, accuracy: 0.001)
    }
    
    func testACompanionStopsBeingLiveWhenTheirOwnCigaretteGoesOut() {
        let lit = Date(timeIntervalSince1970: 1_000_000)
        let them = beside("one", startedAt: lit)
        
        XCTAssertTrue(them.isLive(at: lit))
        XCTAssertTrue(them.isLive(at: lit.addingTimeInterval(Date.breakLength - 1)))
        XCTAssertFalse(them.isLive(at: lit.addingTimeInterval(Date.breakLength)))
    }
    
    /// The whole reason this payload can be queued. An application context
    /// is delivered when the watch next runs, which may be a long time, and
    /// what stops it drawing somebody who left an hour ago is this.
    func testALatePayloadDrawsNobody() {
        let lit = Date(timeIntervalSince1970: 1_000_000)
        let company = BreakCompany(beside: [
            beside("one", startedAt: lit),
            beside("two", startedAt: lit.addingTimeInterval(60), onLeft: false)
        ])
        
        XCTAssertEqual(company.standing(at: lit.addingTimeInterval(30)).count, 2)
        
        // The first one's cigarette is out, the second one's is not.
        XCTAssertEqual(company.standing(at: lit.addingTimeInterval(Date.breakLength + 1)).map(\.id), ["two"])
        
        XCTAssertTrue(company.standing(at: lit.addingTimeInterval(3600)).isEmpty)
    }
    
    func testCompanySurvivesEncodingAndDecoding() throws {
        let lit = Date(timeIntervalSince1970: 1_000_000)
        let original = BreakCompany(beside: [
            BreakCompany.Companion(
                id: "wait-id",
                name: "Paper Kestrel",
                design: CigDesign(title: "Paper Kestrel",
                                  glow: Color(red: 1, green: 0.2, blue: 0)),
                startedAt: lit,
                onLeft: true
            )
        ])
        
        let payload = try XCTUnwrap(original.payload())
        let back = try XCTUnwrap(BreakCompany(payload: payload))
        
        // Field by field, and colours through `codable`, for the reason
        // CigDesignCodableTests does the same: a Color that has been through
        // JSON holds the same three numbers as the one it came from without
        // being `==` to it, so comparing whole designs would fail on a
        // payload that is perfectly correct.
        XCTAssertEqual(back.beside.count, 1)
        
        let them = try XCTUnwrap(back.beside.first)
        XCTAssertEqual(them.id, "wait-id")
        XCTAssertEqual(them.name, "Paper Kestrel")
        XCTAssertEqual(them.onLeft, true)
        XCTAssertEqual(them.startedAt.timeIntervalSince1970, lit.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(them.design.title, "Paper Kestrel")
        
        let glow = them.design.glow.codable
        let sent = original.beside[0].design.glow.codable
        XCTAssertEqual(glow.red, sent.red, accuracy: 0.0001)
        XCTAssertEqual(glow.green, sent.green, accuracy: 0.0001)
        XCTAssertEqual(glow.blue, sent.blue, accuracy: 0.0001)
    }
    
    /// The keys are the contract. A watch on an older build reads these
    /// names and nothing else, so renaming one is the same as sending it
    /// nothing.
    func testTheCompanyKeysHaveNotDrifted() throws {
        let payload = try XCTUnwrap(BreakCompany(beside: [
            beside("one", startedAt: Date(timeIntervalSince1970: 1_000_000))
        ]).payload())
        
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: payload) as? [String: Any]
        )
        XCTAssertEqual(Array(json.keys), ["beside"])
        
        let first = try XCTUnwrap((json["beside"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(first.keys), ["id", "name", "design", "startedAt", "onLeft"])
    }
    
    /// Decoded field by field, the way the saved file and CigDesign are: a
    /// payload from a build that did not have one of these fields yet still
    /// arrives, rather than the whole message failing.
    func testAPayloadMissingFieldsStillArrives() throws {
        let json = """
        {"beside": [{"id": "wait-id"}]}
        """
        let back = try XCTUnwrap(BreakCompany(payload: Data(json.utf8)))
        let them = try XCTUnwrap(back.beside.first)
        
        XCTAssertEqual(them.id, "wait-id")
        XCTAssertEqual(them.name, "")
        XCTAssertEqual(them.design, CigDesign())
        XCTAssertFalse(them.onLeft)
        
        // No ignition instant means nothing can be drawn at a known
        // position, so they are simply not out here.
        XCTAssertFalse(them.isLive())
        XCTAssertTrue(back.standing().isEmpty)
    }
    
    /// Somebody with no id is not somebody: nothing can be keyed on them,
    /// and the phone keys its own views on the same field.
    func testACompanionWithNoIdIsDropped() throws {
        let json = """
        {"beside": [{"name": "Paper Kestrel"}, {"id": "real", "name": "Charcoal Gull"}]}
        """
        let back = try XCTUnwrap(BreakCompany(payload: Data(json.utf8)))
        
        XCTAssertEqual(back.beside.map(\.id), ["real"])
    }
    
    func testAnEmptyCompanyIsNobody() throws {
        XCTAssertTrue(BreakCompany.nobody.isEmpty)
        XCTAssertTrue(BreakCompany.nobody.standing().isEmpty)
        
        let payload = try XCTUnwrap(BreakCompany.nobody.payload())
        XCTAssertEqual(BreakCompany(payload: payload), BreakCompany.nobody)
        
        // Not a failure, just nobody: a payload that is not a company at all
        // comes back nil, and both readers treat nil as nobody.
        XCTAssertNil(BreakCompany(payload: Data("not json".utf8)))
    }
}
