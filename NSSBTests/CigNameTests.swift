//
//  CigNameTests.swift
//  NSSBTests
//

// The name is the identity a stranger sees in the courtyard, and nobody can
// type one any more - so the vocabulary and the re-roll mechanics are the only
// thing standing between a user and a nameless cigarette.

import XCTest
@testable import NSSB

final class CigNameTests: XCTestCase {
    
    func testGeneratedNameIsTwoCapitalisedWords() {
        for _ in 0..<200 {
            let name = randomCigaretteName()
            let words = name.split(separator: " ")
            XCTAssertEqual(words.count, 2, "\(name) is not two words")
            for word in words {
                XCTAssertTrue(word.first?.isUppercase == true, "\(name) is not capitalised")
            }
            XCTAssertFalse(name.contains(where: \.isNumber), "\(name) still has digits")
            XCTAssertFalse(name.contains("-"), "\(name) contains a hyphen")
        }
    }
    
    func testGeneratedNameIsAlwaysRecognisedAsAPoolName() {
        for _ in 0..<200 {
            let name = randomCigaretteName()
            XCTAssertNotNil(cigNameParts(name), "\(name) did not parse back")
            XCTAssertFalse(isLegacyCigName(name), "\(name) read as a legacy name")
        }
    }
    
    func testTheTwoHalvesAreNeverTheSameWord() {
        for _ in 0..<500 {
            let parts = cigNameParts(randomCigaretteName())
            XCTAssertNotEqual(parts?.adjective.lowercased(), parts?.noun.lowercased())
        }
    }
    
    // MARK: Legacy names
    
    func testTypedNamesAreRecognisedAsLegacy() {
        for typed in ["Dad's Brand", "Last One I Swear", "nonsense", "Hollow"] {
            XCTAssertTrue(isLegacyCigName(typed), "\(typed) should be legacy")
        }
    }
    
    func testBlankTitlesAreUnnamedRatherThanLegacy() {
        // A strikethrough over nothing looks like a bug, so whitespace counts
        // as never-named rather than as something to migrate.
        for blank in ["", " ", "   ", "\n", "\t "] {
            XCTAssertFalse(isLegacyCigName(blank), "\(blank.debugDescription) should read as unnamed")
        }
    }
    
    func testEmptyNameIsUnnamedRatherThanLegacy() {
        XCTAssertFalse(isLegacyCigName(""))
        XCTAssertNil(cigNameParts(""))
    }
    
    func testTwoWordsNotFromTheVocabularyAreLegacy() {
        XCTAssertTrue(isLegacyCigName("Zebra Spaceship"))
        XCTAssertNil(cigNameParts("Zebra Spaceship"))
    }
    
    // MARK: Re-rolling one wheel
    
    func testRerollingTheAdjectiveKeepsTheNoun() {
        for _ in 0..<200 {
            let before = randomCigaretteName()
            let after = rerollCigAdjective(in: before)
            guard let b = cigNameParts(before), let a = cigNameParts(after) else {
                return XCTFail("\(before) -> \(after) did not parse")
            }
            XCTAssertEqual(b.noun, a.noun, "the noun moved")
            XCTAssertNotEqual(b.adjective, a.adjective, "the adjective did not change")
        }
    }
    
    func testRerollingTheNounKeepsTheAdjective() {
        for _ in 0..<200 {
            let before = randomCigaretteName()
            let after = rerollCigNoun(in: before)
            guard let b = cigNameParts(before), let a = cigNameParts(after) else {
                return XCTFail("\(before) -> \(after) did not parse")
            }
            XCTAssertEqual(b.adjective, a.adjective, "the adjective moved")
            XCTAssertNotEqual(b.noun, a.noun, "the noun did not change")
        }
    }
    
    /// A tap on a word must always visibly do something.
    func testRerollNeverReturnsTheWordItReplaced() {
        var name = randomCigaretteName()
        for _ in 0..<300 {
            let next = Bool.random() ? rerollCigAdjective(in: name) : rerollCigNoun(in: name)
            XCTAssertNotEqual(next, name, "a re-roll was a no-op")
            name = next
        }
    }
    
    /// Rolling from a legacy or empty title produces a whole fresh name rather
    /// than trying to keep half of something that was never two words.
    func testRerollingFromALegacyNameProducesAPoolName() {
        for seed in ["", "Dad's Brand", "Zebra Spaceship"] {
            XCTAssertNotNil(cigNameParts(rerollCigAdjective(in: seed)))
            XCTAssertNotNil(cigNameParts(rerollCigNoun(in: seed)))
        }
    }
    
    // MARK: The vocabulary itself
    
    func testVocabularyContainsNothingUnpublishable() {
        
        // The old generator drew nouns from a general English dictionary. These
        // are the words that were in it, and must never come back.
        let banned: Set<String> = [
            "abortion", "abuse", "bomb", "cancer", "death", "gun", "racism",
            "rape", "slave", "suicide", "terrorist", "abdomen", "pancreas",
            "vomit", "atm", "cd", "suv", "tv"
        ]
        
        var seen = Set<String>()
        for _ in 0..<4000 {
            for word in randomCigaretteName().split(separator: " ") {
                seen.insert(word.lowercased())
            }
        }
        
        let hits = seen.intersection(banned)
        XCTAssertTrue(hits.isEmpty, "vocabulary still contains \(hits.sorted())")
    }
    
    func testNamesStayShortEnoughForTheRules() {
        // firestore.rules caps the published name at 32 characters.
        for _ in 0..<2000 {
            XCTAssertLessThanOrEqual(randomCigaretteName().count, 32)
        }
    }
}
