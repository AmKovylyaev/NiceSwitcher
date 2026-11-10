import Foundation
import XCTest
@testable import NiceSwitcherCore

final class WordExceptionsTests: XCTestCase {
    func testExceptionsMatchCaseAndCanonicalUnicodeWithoutIgnoringDiacritics() {
        let exceptions = WordExceptions(words: ["Café", "McDonald"])

        XCTAssertTrue(exceptions.contains("CAFÉ"))
        XCTAssertTrue(exceptions.contains("Cafe\u{301}"))
        XCTAssertTrue(exceptions.contains("mcdonald"))
        XCTAssertFalse(exceptions.contains("Cafe"))
    }

    func testAddAndRemoveUseTheSameNormalizedComparison() {
        var exceptions = WordExceptions()
        exceptions.add("Résumé")

        XCTAssertTrue(exceptions.contains("RÉSUMÉ"))
        XCTAssertTrue(exceptions.contains("Re\u{301}sume\u{301}"))

        exceptions.remove("re\u{301}sume\u{301}")
        XCTAssertFalse(exceptions.contains("Résumé"))
    }
}
