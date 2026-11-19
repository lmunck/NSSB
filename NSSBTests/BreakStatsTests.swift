//
//  BreakStatsTests.swift
//  NSSBTests
//

// The numbers under the cigarette. breaksTotal() deliberately excludes a break
// that is still burning, which is why the phone and watch once disagreed.

import XCTest
@testable import NSSB

final class BreakStatsTests: XCTestCase {
    
    private var now: Date { Date.now }
    
    func testTotalExcludesABreakStillBurning() {
        let finished = [now.addingTimeInterval(-10_000), now.addingTimeInterval(-20_000)]
        let burning = now.addingTimeInterval(-10)
        
        XCTAssertEqual(finished.breaksTotal(), 2)
        XCTAssertEqual((finished + [burning]).breaksTotal(), 2, "a lit cigarette is not yet a break")
        XCTAssertEqual((finished + [burning]).count, 3, "but it is still in the array")
    }
    
    func testTodayCountsOnlyToday() {
        let today = [now.addingTimeInterval(-7_200), now.addingTimeInterval(-10_000)]
        let longAgo = [now.addingTimeInterval(-86_400 * 5)]
        
        XCTAssertEqual((today + longAgo).breaksToday(), today.count)
    }
    
    func testSavingsScaleWithPackPrice() {
        let breaks = Array(repeating: now.addingTimeInterval(-10_000), count: 20)
        
        // Twenty breaks is one pack.
        XCTAssertEqual(breaks.savingsTotal(costPer20: 60), 60, accuracy: 0.001)
        XCTAssertEqual(breaks.savingsTotal(costPer20: 0), 0, accuracy: 0.001)
    }
    
    func testEmptyHistoryDoesNotCrashOrDivideByZero() {
        let none: [Date] = []
        XCTAssertEqual(none.breaksTotal(), 0)
        XCTAssertEqual(none.breaksToday(), 0)
        XCTAssertEqual(none.savingsTotal(costPer20: 60), 0, accuracy: 0.001)
        XCTAssertFalse(none.breaksDailyAvg().isNaN, "daily average went NaN on an empty history")
    }
    
    func testBreakIsActiveMatchesTheBreakLength() {
        XCTAssertTrue(now.addingTimeInterval(-1).breakIsActive)
        XCTAssertTrue(now.addingTimeInterval(-(Date.breakLength - 5)).breakIsActive)
        XCTAssertFalse(now.addingTimeInterval(-(Date.breakLength + 5)).breakIsActive)
    }
}

/// What the phone and the watch do with each other's copy.
///
/// The merge is ordered by `lastUpdate`, so what that field means is the
/// whole of whether any of this works. It used to be stamped at send time by
/// both devices, which made every message the newest thing either of them had
/// ever seen - so whichever device spoke last won outright. Raising your wrist
/// is a device speaking, and a watch that had never heard about the running
/// cigarette sent a nil break and put it out.
final class WatchSyncTests: XCTestCase {

    // MARK: What the stamp means

    func testSendingSomethingTwiceDoesNotMakeItNewer() {

        let stamped = Date.now.addingTimeInterval(-3600)
        var data = sample(lastUpdate: stamped)

        // Exactly what a send does: hand over the copy as it stands.
        data.touch(ifChangedFrom: data)

        XCTAssertEqual(data.lastUpdate, stamped, "sending it is not changing it")
    }

    func testChangingSomethingMovesTheStamp() {

        let before = sample(lastUpdate: Date.now.addingTimeInterval(-3600))
        var after = before
        after.breakStarted = .now

        after.touch(ifChangedFrom: before)

        XCTAssertGreaterThan(after.lastUpdate, before.lastUpdate)
    }

    /// The change was made on the other device, at the moment it carries.
    func testACopyThatArrivedKeepsTheStampItCameWith() {

        let mine = sample(lastUpdate: Date.now.addingTimeInterval(-3600))
        let theirStamp = Date.now.addingTimeInterval(-60)
        var merged = mine
        merged.costPer20 = 95
        merged.lastUpdate = theirStamp

        merged.touch(ifChangedFrom: mine)

        XCTAssertEqual(merged.lastUpdate, theirStamp)
    }

    // MARK: The cigarette

    /// The bug, as reported: "when I checked on my watch, it reset the
    /// session and I could no longer join anyone."
    func testAWatchThatNeverHeardAboutTheBreakDoesNotPutItOut() {

        let lit = Date.now.addingTimeInterval(-30)

        var phone = sample(lastUpdate: lit)
        phone.breakStarted = lit

        // The watch has been asleep since this morning. It knows nothing
        // about the cigarette, and silence is not a decision.
        let watch = sample(lastUpdate: Date.now.addingTimeInterval(-8 * 3600))

        let merged = phone.merge(from: watch) ?? phone

        XCTAssertEqual(merged.breakStarted, lit, "the watch put out a cigarette it had never seen")
    }

    /// And the other half, which must keep working: stubbing out on the
    /// watch is a decision, and it has to carry.
    func testStubbingOutOnTheWatchStillPutsItOut() {

        let lit = Date.now.addingTimeInterval(-30)

        var phone = sample(lastUpdate: lit)
        phone.breakStarted = lit

        // Touched after the cigarette was lit, with no break on it.
        let watch = sample(lastUpdate: Date.now)

        let merged = phone.merge(from: watch)

        XCTAssertNotNil(merged, "the stub-out was dropped")
        XCTAssertNil(merged?.breakStarted)
    }

    /// The device that missed the light picks it up, which is what makes the
    /// watch show a cigarette lit on the phone.
    func testTheDeviceThatMissedTheLightAdoptsIt() {

        let lit = Date.now.addingTimeInterval(-30)

        let watch = sample(lastUpdate: Date.now.addingTimeInterval(-8 * 3600))
        var phone = sample(lastUpdate: lit)
        phone.breakStarted = lit

        let merged = watch.merge(from: phone)

        XCTAssertEqual(merged?.breakStarted, lit)
    }

    /// Breaks are a union whoever is newer, because a finished cigarette on
    /// either device happened and neither copy can be the loser of it.
    func testFinishedBreaksAreKeptFromBothSides() {

        let mine = Date.now.addingTimeInterval(-10_000)
        let theirs = Date.now.addingTimeInterval(-20_000)

        var phone = sample(lastUpdate: Date.now)
        phone.breaks = [mine]

        var watch = sample(lastUpdate: Date.now.addingTimeInterval(-8 * 3600))
        watch.breaks = [theirs]

        let merged = phone.merge(from: watch)

        XCTAssertEqual(merged?.breaks, [theirs, mine].sorted())
    }

    private func sample(lastUpdate: Date) -> NonSmokingData {
        var design = CigDesign()
        design.title = "Sunlit Parchment"
        return NonSmokingData(breaks: [], breakStarted: nil, costPer20: 60,
                              accentHue: 220, cigDesign: design, lastUpdate: lastUpdate)
    }
}
