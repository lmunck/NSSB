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
