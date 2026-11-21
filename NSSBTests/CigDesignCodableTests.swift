//
//  CigDesignCodableTests.swift
//  NSSBTests
//

// CigDesign is a wire format: the saved file, watch payloads, share URLs and
// Firestore documents. The encoding must not drift, because data written by
// older builds has to keep decoding.

import XCTest
import SwiftUI
@testable import NSSB

final class CigDesignCodableTests: XCTestCase {
    
    /// Exactly the shape the old `extension Color: Codable` produced, taken
    /// from a real userData file written before CodableColor existed.
    private let legacyJSON = """
    {
      "title": "Nimble Roebuck",
      "widthPercentage": 0.1,
      "glowPercentage": 0.1,
      "filterPercentage": 0.25,
      "filter": {"red": 1, "green": 0.800000011920929, "blue": 0.5},
      "body":   {"red": 1, "green": 1, "blue": 1},
      "ash":    {"red": 0.4, "green": 0.4, "blue": 0.4},
      "glow":   {"red": 1, "green": 0.2, "blue": 0},
      "background": {"red": 0.2, "green": 0.4, "blue": 0.9}
    }
    """
    
    func testDecodesDataWrittenBeforeTheCodableColorChange() throws {
        let design = try JSONDecoder().decode(CigDesign.self, from: Data(legacyJSON.utf8))
        
        XCTAssertEqual(design.title, "Nimble Roebuck")
        XCTAssertEqual(design.filterPercentage, 0.25, accuracy: 0.0001)
        
        let filter = design.filter.codable
        XCTAssertEqual(filter.red, 1, accuracy: 0.001)
        XCTAssertEqual(filter.green, 0.8, accuracy: 0.001)
        XCTAssertEqual(filter.blue, 0.5, accuracy: 0.001)
    }
    
    func testEncodingKeepsTheSameKeysAndColourShape() throws {
        let data = try JSONEncoder().encode(CigDesign(title: "Hollow Lantern"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        XCTAssertEqual(
            Set(object.keys),
            ["title", "widthPercentage", "glowPercentage", "filterPercentage",
             "filter", "body", "ash", "glow", "background"]
        )
        
        for key in ["filter", "body", "ash", "glow", "background"] {
            let colour = try XCTUnwrap(object[key] as? [String: Any], "\(key) is not an object")
            XCTAssertEqual(Set(colour.keys), ["red", "green", "blue"], "\(key) changed shape")
        }
    }
    
    func testRoundTripPreservesTheDesign() throws {
        let original = CigDesign(title: "Burnt Lighthouse", widthPercentage: 0.37,
                                 filterPercentage: 0.3,
                                 glow: Color(red: 1, green: 0.55, blue: 0.16))
        let back = try JSONDecoder().decode(CigDesign.self, from: JSONEncoder().encode(original))
        
        XCTAssertEqual(original.title, back.title)
        XCTAssertEqual(original.widthPercentage, back.widthPercentage, accuracy: 0.0001)
        
        // Not exact equality: Color keeps its components as Float, so a trip
        // through CodableColor's Doubles loses precision after about the
        // seventh decimal. Irrelevant on screen, fatal to ==.
        XCTAssertEqual(original.glow.codable.red, back.glow.codable.red, accuracy: 0.0001)
        XCTAssertEqual(original.glow.codable.green, back.glow.codable.green, accuracy: 0.0001)
        XCTAssertEqual(original.glow.codable.blue, back.glow.codable.blue, accuracy: 0.0001)
    }
    
    /// A dynamic system colour has no fixed RGB until it is resolved, so
    /// encoding freezes whatever it resolved to. Worth knowing, because
    /// CigDesign.background defaults to .accent: once a design is saved or
    /// published, its colours stop following the system.
    func testDynamicColoursAreFrozenWhenEncoded() throws {
        let design = CigDesign(glow: .red)
        let back = try JSONDecoder().decode(CigDesign.self, from: JSONEncoder().encode(design))
        
        let frozen = back.glow.codable
        XCTAssertEqual(frozen.red, Color.red.codable.red, accuracy: 0.0001)
        XCTAssertEqual(frozen.green, Color.red.codable.green, accuracy: 0.0001)
    }
    
    /// The old encoder wrote nothing at all for a colour it could not read,
    /// producing an empty object. Decoding must survive that rather than
    /// losing the whole design.
    func testACorruptedColourFallsBackInsteadOfFailingTheDecode() throws {
        let broken = """
        {"title": "Half Broken", "widthPercentage": 0.2, "glowPercentage": 0.1,
         "filterPercentage": 0.25, "filter": {}, "body": {"red":1,"green":1,"blue":1},
         "ash": {}, "glow": {}, "background": {}}
        """
        let design = try JSONDecoder().decode(CigDesign.self, from: Data(broken.utf8))
        XCTAssertEqual(design.title, "Half Broken", "the rest of the design survived")
    }
    
    func testCodableColorFallsBackForAColourWithNoRGB() {
        // A gradient-backed or otherwise non-RGB colour must not encode as nothing.
        let c = CodableColor(Color.clear)
        XCTAssertTrue((0...1).contains(c.red))
        XCTAssertTrue((0...1).contains(c.green))
        XCTAssertTrue((0...1).contains(c.blue))
    }
}

/// NonSmokingData is the saved file and the watch payload. A field that is
/// missing or unreadable must not cost the user their whole break history.
final class NonSmokingDataCodableTests: XCTestCase {
    
    func testAnEmptyObjectDecodesToDefaults() throws {
        let data = try JSONDecoder().decode(NonSmokingData.self, from: Data("{}".utf8))
        XCTAssertTrue(data.breaks.isEmpty)
        XCTAssertNil(data.breakStarted)
        XCTAssertEqual(data.costPer20, 0)
        XCTAssertEqual(data.lastUpdate, .distantPast)
    }
    
    func testAMissingFieldKeepsTheRest() throws {
        let json = #"{"breaks": [100, 200], "costPer20": 42.5}"#
        let data = try JSONDecoder().decode(NonSmokingData.self, from: Data(json.utf8))
        XCTAssertEqual(data.breaks.count, 2)
        XCTAssertEqual(data.costPer20, 42.5)
        XCTAssertEqual(data.lastUpdate, .distantPast, "no stamp means older than anything")
    }
    
    func testAnUnreadableFieldKeepsTheHistory() throws {
        let json = #"{"breaks": [100, 200], "costPer20": "expensive", "lastUpdate": 300}"#
        let data = try JSONDecoder().decode(NonSmokingData.self, from: Data(json.utf8))
        XCTAssertEqual(data.breaks.count, 2, "the break history survived")
        XCTAssertEqual(data.costPer20, 0)
        XCTAssertEqual(data.lastUpdate, Date(timeIntervalSinceReferenceDate: 300))
    }
    
    func testRoundTrip() throws {
        var original = NonSmokingData(lastUpdate: Date(timeIntervalSinceReferenceDate: 1_000))
        original.breaks = [Date(timeIntervalSinceReferenceDate: 500)]
        original.breakStarted = Date(timeIntervalSinceReferenceDate: 900)
        original.costPer20 = 12
        original.accentHue = 100
        let decoded = try JSONDecoder().decode(NonSmokingData.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.breaks, original.breaks)
        XCTAssertEqual(decoded.breakStarted, original.breakStarted)
        XCTAssertEqual(decoded.costPer20, original.costPer20)
        XCTAssertEqual(decoded.accentHue, original.accentHue)
        XCTAssertEqual(decoded.lastUpdate, original.lastUpdate)
        XCTAssertEqual(decoded.cigDesign.title, original.cigDesign.title)
    }
}
