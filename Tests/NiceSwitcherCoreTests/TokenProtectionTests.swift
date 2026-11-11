import Foundation
import XCTest
@testable import NiceSwitcherCore

final class TokenProtectionTests: XCTestCase {
    func testOnlyPlainTextSurfaceCanBeAnalyzed() {
        XCTAssertTrue(TokenProtection.permits("hello", surface: .plainText))

        for surface in [TokenSurface.code, .address, .secure, .unknown] {
            XCTAssertFalse(TokenProtection.permits("hello", surface: surface))
        }
    }

    func testProtectsURLsDomainsEmailAndPaths() {
        let protected = [
            "https://example.com/path",
            "http://example.com",
            "www.example.com",
            "example.com",
            "user@example.com",
            "/tmp/file",
            "C:\\Users\\name",
            "~/Documents/file"
        ]

        for token in protected {
            XCTAssertFalse(TokenProtection.permits(token, surface: .plainText), "Should protect \(token)")
        }
    }

    func testProtectsCodeIdentifiersDigitsAndAllCaps() {
        let protected = ["snake_case", "myVariable", "URLParser", "hello123", "API", "`abc"]

        for token in protected {
            XCTAssertFalse(TokenProtection.permits(token, surface: .plainText), "Should protect \(token)")
        }
    }

    func testProtectsMixedScriptsEmojiControlsWhitespaceAndShortTokens() {
        let protected = ["cтарт", "hello🙂", "hello\u{0007}", "hello world", "hi"]

        for token in protected {
            XCTAssertFalse(TokenProtection.permits(token, surface: .plainText), "Should protect \(token)")
        }
    }

    func testRejectsOversizedTokensAndGraphemeClusters() {
        let oversizedGrapheme = "a" + String(repeating: "\u{301}", count: 256)
        XCTAssertEqual(oversizedGrapheme.count, 1)
        XCTAssertEqual(oversizedGrapheme.unicodeScalars.count, 257)

        XCTAssertFalse(TokenProtection.permits(String(repeating: "a", count: 65), surface: .plainText))
        XCTAssertFalse(TokenProtection.permits(oversizedGrapheme, surface: .plainText))
    }

    func testAllowsOrdinaryEnglishAndRussianWords() {
        XCTAssertTrue(TokenProtection.permits("hello", surface: .plainText))
        XCTAssertTrue(TokenProtection.permits("привет", surface: .plainText))
        XCTAssertTrue(TokenProtection.permits("Ghbdtn", surface: .plainText))
    }
}
