//
//  CourtyardTests.swift
//  NSSBTests
//

// Where people stand. The positions are derived from the break id rather than
// from array order, because a snapshot arriving must not make the whole
// courtyard rearrange itself while someone is looking at it.

import XCTest
@testable import NSSB

final class CourtyardTests: XCTestCase {
    
    func testAPositionIsStableForTheSameBreak() {
        let a = Courtyard.position(for: "break-abc")
        let b = Courtyard.position(for: "break-abc")
        
        XCTAssertEqual(a.x, b.x)
        XCTAssertEqual(a.y, b.y)
        XCTAssertEqual(a.depth, b.depth)
    }
    
    func testDifferentBreaksGetDifferentPositions() {
        let positions = (0..<40).map { Courtyard.position(for: "break-\($0)") }
        let distinct = Set(positions.map { "\($0.x)-\($0.y)" })
        
        XCTAssertGreaterThan(distinct.count, 30, "too many people standing in the same spot")
    }
    
    func testEveryoneStaysOnScreen() {
        for i in 0..<500 {
            let p = Courtyard.position(for: UUID().uuidString + "\(i)")
            XCTAssertTrue((0...1).contains(p.x), "x off screen: \(p.x)")
            XCTAssertTrue((0...1).contains(p.y), "y off screen: \(p.y)")
            XCTAssertTrue((0...1).contains(p.depth))
        }
    }
    
    /// Your own cigarette stands in the centre column. Nobody else should.
    func testNobodyStandsWhereYouDo() {
        for i in 0..<500 {
            let x = Courtyard.position(for: UUID().uuidString + "\(i)").x
            XCTAssertFalse((0.36...0.64).contains(x), "a stranger is standing on top of you at \(x)")
        }
    }
    
    func testNobodyStandsOnTheScoreRow() {
        for i in 0..<500 {
            let y = Courtyard.position(for: UUID().uuidString + "\(i)").y
            XCTAssertLessThan(y, 0.8, "a cigarette is drawn over the numbers")
        }
    }
    
    // MARK: Flags
    
    func testFlagComesFromTheRegionCode() {
        XCTAssertEqual(presence(country: "DK").flag, "🇩🇰")
        XCTAssertEqual(presence(country: "pt").flag, "🇵🇹", "lowercase should still work")
        XCTAssertEqual(presence(country: "JP").flag, "🇯🇵")
    }
    
    func testNoFlagWhenTheCountryIsWithheldOrNonsense() {
        XCTAssertNil(presence(country: nil).flag)
        XCTAssertNil(presence(country: "").flag)
        XCTAssertNil(presence(country: "DNK").flag, "three letters is not a region code")
    }
    
    private func presence(country: String?) -> BreakPresence {
        BreakPresence(
            id: "x", ownerHash: "h", startedAt: .now,
            endsAt: Date.now.addingTimeInterval(300),
            name: "Hollow Lantern", country: country, tzOffset: 0,
            design: CigDesign()
        )
    }
}
