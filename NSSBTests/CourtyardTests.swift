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
    
    // MARK: Keeping out of the way of whoever is already with you
    
    /// The two places somebody can stand beside you and the courtyard's two
    /// columns are the same two columns, so an unlit cigarette asking for a
    /// light was coming out directly behind a companion about half the time.
    /// Something you have to find and tap in eight seconds cannot be behind
    /// something else.
    
    func testAnEmptyCourtyardChangesNobodysSpot() {
        
        for i in 0..<40 {
            let name = "Paper Kestrel \(i)"
            let plain = Courtyard.position(for: name)
            let avoiding = Courtyard.position(for: name, avoiding: [])
            
            XCTAssertEqual(plain.x, avoiding.x)
            XCTAssertEqual(plain.y, avoiding.y)
            XCTAssertEqual(plain.depth, avoiding.depth)
        }
    }
    
    func testSomebodyComesOutOnTheFreeSide() {
        
        for i in 0..<40 {
            
            let name = "Quiet Sparrow \(i)"
            let natural = Courtyard.position(for: name)
            let side: CompanionSide = natural.x < 0.5 ? .left : .right
            
            let moved = Courtyard.position(for: name, avoiding: [side])
            XCTAssertEqual(moved.x > 0.5, side == .left,
                           "\(name) stayed on a side that was taken")
            
            let stayed = Courtyard.position(for: name, avoiding: [side.opposite])
            XCTAssertEqual(stayed.x, natural.x,
                           "\(name) moved out of a column nobody was standing in")
        }
    }
    
    func testWithBothSidesTakenTheyComeOutAtTheEdge() {
        
        for i in 0..<40 {
            
            let name = "Brass Kestrel \(i)"
            let edge = Courtyard.position(for: name, avoiding: [.left, .right])
            
            // Outside both columns, which start at 0.06 and end at 0.94.
            XCTAssertTrue(edge.x < 0.06 || edge.x > 0.94,
                          "\(name) came out at \(edge.x), still in front of somebody")
            XCTAssertTrue(edge.x > 0 && edge.x < 1, "\(name) came out off the screen")
        }
    }
    
    /// Dodging must not become a second kind of randomness: the same person,
    /// in the same courtyard, stands in the same place.
    func testDodgingIsStillDeterministic() {
        
        let a = Courtyard.position(for: "Hollow Lantern", avoiding: [.left])
        let b = Courtyard.position(for: "Hollow Lantern", avoiding: [.left])
        
        XCTAssertEqual(a.x, b.x)
        XCTAssertEqual(a.y, b.y)
        XCTAssertEqual(a.depth, b.depth)
    }
    
    /// Which side of you somebody ends up on and which column they come out
    /// of are two answers to one question, so they have to come from the
    /// same place. They did not: the side was hashed from the name and the
    /// spot from the document id, so somebody standing on your right walked
    /// across you to stand on your left.
    func testWhereTheyStandAndWhereTheyStoodAgree() {
        
        for i in 0..<40 {
            let name = "Paper Kestrel \(i)"
            let spot = Courtyard.position(for: name)
            let side = Companion.naturalSide(for: name)
            
            XCTAssertEqual(side, spot.x < 0.5 ? .left : .right,
                           "\(name) comes from one side and stands on the other")
        }
    }
    
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
