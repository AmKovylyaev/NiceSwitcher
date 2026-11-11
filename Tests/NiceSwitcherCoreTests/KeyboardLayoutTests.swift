import Foundation
import XCTest
@testable import NiceSwitcherCore

final class KeyboardLayoutTests: XCTestCase {
    func testConvertsEnglishPhysicalStrokesToRussian() {
        let token = TypedToken(
            text: "ghbdtn",
            sourceID: FixtureLayouts.usSourceID,
            strokes: FixtureLayouts.wordStrokes
        )

        XCTAssertEqual(LayoutConverter.convert(token, from: FixtureLayouts.us, to: FixtureLayouts.ru), "привет")
    }

    func testPreservesShiftForCapitalizedConversion() {
        let strokes = [FixtureLayouts.shiftedG] + Array(FixtureLayouts.wordStrokes.dropFirst())
        let token = TypedToken(text: "Ghbdtn", sourceID: FixtureLayouts.usSourceID, strokes: strokes)

        XCTAssertEqual(LayoutConverter.convert(token, from: FixtureLayouts.us, to: FixtureLayouts.ru), "Привет")
    }

    func testConvertsInTheReverseDirection() {
        let token = TypedToken(
            text: "привет",
            sourceID: FixtureLayouts.ruSourceID,
            strokes: FixtureLayouts.wordStrokes
        )

        XCTAssertEqual(LayoutConverter.convert(token, from: FixtureLayouts.ru, to: FixtureLayouts.us), "ghbdtn")
    }

    func testSameKeyWithDifferentModifiersUsesDifferentOutput() {
        let lower = TypedToken(text: "g", sourceID: FixtureLayouts.usSourceID, strokes: [FixtureLayouts.g])
        let upper = TypedToken(text: "G", sourceID: FixtureLayouts.usSourceID, strokes: [FixtureLayouts.shiftedG])

        XCTAssertEqual(LayoutConverter.convert(lower, from: FixtureLayouts.us, to: FixtureLayouts.ru), "п")
        XCTAssertEqual(LayoutConverter.convert(upper, from: FixtureLayouts.us, to: FixtureLayouts.ru), "П")
    }

    func testRejectsUnknownSourceID() {
        let token = TypedToken(text: "ghbdtn", sourceID: "fixture.unknown", strokes: FixtureLayouts.wordStrokes)

        XCTAssertNil(LayoutConverter.convert(token, from: FixtureLayouts.us, to: FixtureLayouts.ru))
    }

    func testAbstainsWhenSourceAndTargetIDsMatchButMappingsDiffer() throws {
        let stroke = FixtureLayouts.g
        let source = try LayoutProfile(sourceID: FixtureLayouts.usSourceID, outputs: [stroke: "g"])
        let targetWithSameID = try LayoutProfile(sourceID: FixtureLayouts.usSourceID, outputs: [stroke: "п"])
        let token = TypedToken(text: "g", sourceID: FixtureLayouts.usSourceID, strokes: [stroke])

        XCTAssertNil(LayoutConverter.convert(token, from: source, to: targetWithSameID))
    }

    func testAbstainsWhenConvertingATokenBackToTheSameProfile() {
        let token = TypedToken(text: "g", sourceID: FixtureLayouts.usSourceID, strokes: [FixtureLayouts.g])

        XCTAssertNil(LayoutConverter.convert(token, from: FixtureLayouts.us, to: FixtureLayouts.us))
    }

    func testRejectsMissingStrokeOutput() {
        let missing = KeyStroke(keyCode: 99, modifiers: [])
        let token = TypedToken(text: "g?", sourceID: FixtureLayouts.usSourceID, strokes: [FixtureLayouts.g, missing])

        XCTAssertNil(LayoutConverter.convert(token, from: FixtureLayouts.us, to: FixtureLayouts.ru))
    }

    func testRejectsSourceTextThatDoesNotMatchThePhysicalOutputs() {
        let token = TypedToken(text: "ghbdtnx", sourceID: FixtureLayouts.usSourceID, strokes: FixtureLayouts.wordStrokes)

        XCTAssertNil(LayoutConverter.convert(token, from: FixtureLayouts.us, to: FixtureLayouts.ru))
    }

    func testUsesUTF16EqualityInsteadOfCanonicalStringEquality() {
        let decomposed = "e\u{301}"
        let precomposed = "é"
        XCTAssertFalse(Array(decomposed.utf16).elementsEqual(precomposed.utf16))
        XCTAssertEqual(decomposed, precomposed, "Swift String equality treats canonical forms as equal")

        let token = TypedToken(
            text: decomposed,
            sourceID: FixtureLayouts.usSourceID,
            strokes: [KeyStroke(keyCode: 20, modifiers: [])]
        )
        XCTAssertNil(LayoutConverter.convert(token, from: FixtureLayouts.us, to: FixtureLayouts.ru))
    }

    func testRejectsAComposedTokenWithoutCommittedOutputsForItsStrokes() {
        let token = TypedToken(
            text: "é",
            sourceID: FixtureLayouts.usSourceID,
            strokes: [KeyStroke(keyCode: 21, modifiers: []), KeyStroke(keyCode: 22, modifiers: [])]
        )

        XCTAssertNil(LayoutConverter.convert(token, from: FixtureLayouts.us, to: FixtureLayouts.ru))
    }

    func testRejectsCommandAndControlStrokesEvenWhenProfilesContainThem() throws {
        for modifier in [KeyModifiers.command, .control] {
            let stroke = KeyStroke(keyCode: 30, modifiers: modifier)
            let source = try LayoutProfile(sourceID: FixtureLayouts.usSourceID, outputs: [stroke: "g"])
            let target = try LayoutProfile(sourceID: FixtureLayouts.ruSourceID, outputs: [stroke: "п"])
            let token = TypedToken(text: "g", sourceID: FixtureLayouts.usSourceID, strokes: [stroke])

            XCTAssertNil(LayoutConverter.convert(token, from: source, to: target))
        }
    }

    func testRejectsMissingTargetOutput() throws {
        let token = TypedToken(text: "g", sourceID: FixtureLayouts.usSourceID, strokes: [FixtureLayouts.g])
        let target = try LayoutProfile(sourceID: FixtureLayouts.ruSourceID, outputs: [:])

        XCTAssertNil(LayoutConverter.convert(token, from: FixtureLayouts.us, to: target))
    }

    func testLayoutProfilesRejectEmptyIDsAndInvalidOutputs() {
        let oversizedGrapheme = "a" + String(repeating: "\u{301}", count: 256)
        XCTAssertEqual(oversizedGrapheme.count, 1)
        XCTAssertEqual(oversizedGrapheme.unicodeScalars.count, 257)

        XCTAssertThrowsError(try LayoutProfile(sourceID: "", outputs: [:]))
        XCTAssertThrowsError(try LayoutProfile(sourceID: "fixture.us", outputs: [FixtureLayouts.g: ""]))
        XCTAssertThrowsError(try LayoutProfile(sourceID: "fixture.us", outputs: [FixtureLayouts.g: "ab"]))
        XCTAssertThrowsError(
            try LayoutProfile(sourceID: "fixture.us", outputs: [FixtureLayouts.g: oversizedGrapheme])
        )
    }

    func testDirectTypedTokenCannotExceedRuntimeLimits() throws {
        let repeatedStroke = KeyStroke(keyCode: 40, modifiers: [])
        let mark = "\u{301}"
        let tooManyStrokesText = String(repeating: mark, count: 65)
        XCTAssertEqual(tooManyStrokesText.count, 1)
        XCTAssertEqual(tooManyStrokesText.unicodeScalars.count, 65)
        let strokeSource = try LayoutProfile(sourceID: FixtureLayouts.usSourceID, outputs: [repeatedStroke: mark])
        let strokeTarget = try LayoutProfile(sourceID: FixtureLayouts.ruSourceID, outputs: [repeatedStroke: mark])
        let tooManyStrokes = TypedToken(
            text: tooManyStrokesText,
            sourceID: FixtureLayouts.usSourceID,
            strokes: Array(repeating: repeatedStroke, count: 65)
        )
        XCTAssertNil(LayoutConverter.convert(tooManyStrokes, from: strokeSource, to: strokeTarget))

        let firstOutput = "a" + String(repeating: mark, count: 255)
        let secondOutput = mark
        let tooManyScalarsText = firstOutput + secondOutput
        XCTAssertEqual(tooManyScalarsText.count, 1)
        XCTAssertEqual(tooManyScalarsText.unicodeScalars.count, 257)
        let firstStroke = KeyStroke(keyCode: 41, modifiers: [])
        let secondStroke = KeyStroke(keyCode: 42, modifiers: [])
        let scalarSource = try LayoutProfile(
            sourceID: FixtureLayouts.usSourceID,
            outputs: [firstStroke: firstOutput, secondStroke: secondOutput]
        )
        let scalarTarget = try LayoutProfile(
            sourceID: FixtureLayouts.ruSourceID,
            outputs: [firstStroke: firstOutput, secondStroke: secondOutput]
        )
        let tooManyScalars = TypedToken(
            text: tooManyScalarsText,
            sourceID: FixtureLayouts.usSourceID,
            strokes: [firstStroke, secondStroke]
        )
        XCTAssertNil(LayoutConverter.convert(tooManyScalars, from: scalarSource, to: scalarTarget))
    }

    func testRejectsConvertedOutputOver256Scalars() throws {
        let firstStroke = KeyStroke(keyCode: 50, modifiers: [])
        let secondStroke = KeyStroke(keyCode: 51, modifiers: [])
        let source = try LayoutProfile(
            sourceID: FixtureLayouts.usSourceID,
            outputs: [firstStroke: "a", secondStroke: "b"]
        )
        let firstTargetOutput = "x" + String(repeating: "\u{301}", count: 128)
        let secondTargetOutput = "y" + String(repeating: "\u{301}", count: 128)
        XCTAssertEqual(firstTargetOutput.count, 1)
        XCTAssertEqual(secondTargetOutput.count, 1)
        XCTAssertEqual(firstTargetOutput.unicodeScalars.count + secondTargetOutput.unicodeScalars.count, 258)
        let target = try LayoutProfile(
            sourceID: FixtureLayouts.ruSourceID,
            outputs: [firstStroke: firstTargetOutput, secondStroke: secondTargetOutput]
        )
        let token = TypedToken(text: "ab", sourceID: FixtureLayouts.usSourceID, strokes: [firstStroke, secondStroke])

        XCTAssertNil(LayoutConverter.convert(token, from: source, to: target))
    }
}
