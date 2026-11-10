import Foundation
import XCTest
@testable import NiceSwitcherCore

final class TokenBufferTests: XCTestCase {
    func testBoundaryReturnsOneTokenAndPreservesProvenance() {
        var buffer = TokenBuffer()
        for (text, stroke) in zip("ghbdtn", FixtureLayouts.wordStrokes) {
            buffer.appendCommitted(text: String(text), stroke: stroke, sourceID: FixtureLayouts.usSourceID)
        }

        let token = buffer.finishWord()
        XCTAssertEqual(token?.text, "ghbdtn")
        XCTAssertEqual(token?.sourceID, FixtureLayouts.usSourceID)
        XCTAssertEqual(token?.strokes, FixtureLayouts.wordStrokes)
        XCTAssertNil(buffer.finishWord())
        XCTAssertEqual(buffer.context, ["ghbdtn"])
    }

    func testAcceptsExactly64GraphemeClusters() {
        var buffer = TokenBuffer()
        for _ in 0..<64 {
            buffer.appendCommitted(text: "a", stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
        }

        XCTAssertEqual(buffer.finishWord()?.text, String(repeating: "a", count: 64))
    }

    func testSuppressesTheWholeTokenAfterThe65thGrapheme() {
        var buffer = TokenBuffer()
        for _ in 0..<65 {
            buffer.appendCommitted(text: "a", stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
        }

        XCTAssertNil(buffer.finishWord())
        XCTAssertNil(buffer.finishWord())
    }

    func testSuppressesTheWholeTokenAfterThe65thStrokeEvenWithinOneGrapheme() {
        var buffer = TokenBuffer()
        buffer.appendCommitted(text: "a", stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
        for _ in 0..<64 {
            buffer.appendCommitted(text: "\u{301}", stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
        }

        XCTAssertEqual(buffer.context, [])
        XCTAssertNil(buffer.finishWord())
    }

    func testSuppressesAGraphemeExceeding256Scalars() {
        var buffer = TokenBuffer()
        let oversized = "a" + String(repeating: "\u{301}", count: 256)
        XCTAssertEqual(oversized.count, 1)
        XCTAssertEqual(oversized.unicodeScalars.count, 257)
        buffer.appendCommitted(text: oversized, stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)

        XCTAssertNil(buffer.finishWord())
    }

    func testSuppressesTheRemainderAfterMidWordSourceChange() {
        var buffer = TokenBuffer()
        buffer.appendCommitted(text: "a", stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
        buffer.appendCommitted(text: "b", stroke: FixtureLayouts.h, sourceID: FixtureLayouts.ruSourceID)
        buffer.appendCommitted(text: "c", stroke: FixtureLayouts.b, sourceID: FixtureLayouts.ruSourceID)

        XCTAssertNil(buffer.finishWord())

        buffer.appendCommitted(text: "d", stroke: FixtureLayouts.d, sourceID: FixtureLayouts.ruSourceID)
        XCTAssertEqual(buffer.finishWord()?.text, "d")
    }

    func testSuppressesTheRemainderAfterInvalidCommittedOutput() {
        var buffer = TokenBuffer()
        buffer.appendCommitted(text: "a", stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
        buffer.appendCommitted(text: "ab", stroke: FixtureLayouts.h, sourceID: FixtureLayouts.usSourceID)
        buffer.appendCommitted(text: "c", stroke: FixtureLayouts.b, sourceID: FixtureLayouts.usSourceID)

        XCTAssertNil(buffer.finishWord())
    }

    func testInvalidationPreservesCompletedContextAndSuppressesUntilBoundary() {
        var buffer = TokenBuffer()
        buffer.appendCommitted(text: "a", stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
        XCTAssertEqual(buffer.finishWord()?.text, "a")

        buffer.appendCommitted(text: "b", stroke: FixtureLayouts.h, sourceID: FixtureLayouts.usSourceID)
        buffer.invalidateCurrentWord()
        buffer.appendCommitted(text: "c", stroke: FixtureLayouts.b, sourceID: FixtureLayouts.usSourceID)
        XCTAssertEqual(buffer.context, ["a"])
        XCTAssertNil(buffer.finishWord())

        buffer.appendCommitted(text: "d", stroke: FixtureLayouts.d, sourceID: FixtureLayouts.usSourceID)
        XCTAssertEqual(buffer.finishWord()?.text, "d")
        XCTAssertEqual(buffer.context, ["a", "d"])
    }

    func testResetClearsContextAndSuppression() {
        var buffer = TokenBuffer()
        buffer.appendCommitted(text: "a", stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
        XCTAssertEqual(buffer.finishWord()?.text, "a")
        buffer.invalidateCurrentWord()
        buffer.reset()

        XCTAssertEqual(buffer.context, [])
        buffer.appendCommitted(text: "b", stroke: FixtureLayouts.h, sourceID: FixtureLayouts.ruSourceID)
        XCTAssertEqual(buffer.finishWord()?.text, "b")
    }

    func testHistoryIsLimitedToFourCompletedWords() {
        var buffer = TokenBuffer()
        for text in ["a", "b", "c", "d", "e"] {
            buffer.appendCommitted(text: text, stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
            XCTAssertEqual(buffer.finishWord()?.text, text)
        }

        XCTAssertEqual(buffer.context, ["b", "c", "d", "e"])
    }

    func testCurrentWordAndHistoryShareThe256ScalarBudget() {
        var buffer = TokenBuffer()
        for _ in 0..<4 {
            buffer.appendCommitted(text: "x", stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
        }
        XCTAssertEqual(buffer.finishWord()?.text, "xxxx")
        XCTAssertEqual(buffer.context, ["xxxx"])

        let oneGraphemeFourScalars = "a\u{301}\u{301}\u{301}"
        XCTAssertEqual(oneGraphemeFourScalars.count, 1)
        for _ in 0..<64 {
            buffer.appendCommitted(text: oneGraphemeFourScalars, stroke: FixtureLayouts.g, sourceID: FixtureLayouts.usSourceID)
        }

        XCTAssertEqual(buffer.context, [])
        let current = buffer.finishWord()
        XCTAssertEqual(current?.text.unicodeScalars.count, 256)
    }
}
