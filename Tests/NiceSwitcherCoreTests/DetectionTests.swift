import Foundation
import XCTest
@testable import NiceSwitcherCore

final class DetectionTests: XCTestCase {
    func testSuggestsKnownRussianWordForUnknownEnglishLayoutInput() throws {
        let lexicon = try WordLexicon(frequencies: [
            FixtureLayouts.ruSourceID: ["привет": 100]
        ])
        let token = TypedToken(
            text: "ghbdtn",
            sourceID: FixtureLayouts.usSourceID,
            strokes: FixtureLayouts.wordStrokes
        )

        XCTAssertEqual(
            Detector.decide(
                token: token,
                source: FixtureLayouts.us,
                target: FixtureLayouts.ru,
                surface: .plainText,
                exceptions: WordExceptions(),
                lexicon: lexicon
            ),
            .suggestion(CorrectionCandidate(
                original: "ghbdtn",
                replacement: "привет",
                targetSourceID: FixtureLayouts.ruSourceID
            ))
        )
    }

    func testSuggestsKnownEnglishWordForReverseLayoutInput() throws {
        let strokes = (0..<5).map { KeyStroke(keyCode: UInt16(100 + $0)) }
        let source = try LayoutProfile(
            sourceID: "fixture.ru.reverse",
            outputs: Dictionary(uniqueKeysWithValues: zip(strokes, ["р", "у", "д", "д", "щ"]))
        )
        let target = try LayoutProfile(
            sourceID: "fixture.us.reverse",
            outputs: Dictionary(uniqueKeysWithValues: zip(strokes, ["h", "e", "l", "l", "o"]))
        )
        let token = TypedToken(text: "руддщ", sourceID: source.sourceID, strokes: strokes)
        let lexicon = try WordLexicon(frequencies: [target.sourceID: ["hello": 7]])

        XCTAssertEqual(
            Detector.decide(
                token: token,
                source: source,
                target: target,
                surface: .plainText,
                exceptions: WordExceptions(),
                lexicon: lexicon
            ),
            .suggestion(CorrectionCandidate(
                original: "руддщ",
                replacement: "hello",
                targetSourceID: target.sourceID
            ))
        )
    }

    func testAbstainsWhenBothOriginalAndCandidateAreKnownWords() throws {
        let lexicon = try WordLexicon(frequencies: [
            FixtureLayouts.usSourceID: ["ghbdtn": 2],
            FixtureLayouts.ruSourceID: ["привет": 100]
        ])
        let decision = decide("ghbdtn", sourceID: FixtureLayouts.usSourceID, lexicon: lexicon)

        XCTAssertEqual(decision, .abstain(.originalKnown))
    }

    func testAbstainsWhenOriginalIsKnownInTargetDictionary() throws {
        let lexicon = try WordLexicon(frequencies: [
            FixtureLayouts.ruSourceID: ["ghbdtn": 2, "привет": 100]
        ])

        XCTAssertEqual(
            decide("ghbdtn", sourceID: FixtureLayouts.usSourceID, lexicon: lexicon),
            .abstain(.originalKnown)
        )
    }

    func testAbstainsWhenCandidateIsUnknownInTargetDictionary() throws {
        let lexicon = try WordLexicon(frequencies: [FixtureLayouts.ruSourceID: ["добрый": 12]])

        XCTAssertEqual(
            decide("ghbdtn", sourceID: FixtureLayouts.usSourceID, lexicon: lexicon),
            .abstain(.unknownCandidate)
        )
    }

    func testAbstainsWhenOriginalAndCandidateAreBothUnknown() throws {
        let lexicon = try WordLexicon(frequencies: [:])

        XCTAssertEqual(
            decide("ghbdtn", sourceID: FixtureLayouts.usSourceID, lexicon: lexicon),
            .abstain(.unknownCandidate)
        )
    }

    func testAbstainsForAnExplicitExceptionBeforeConsideringCandidate() throws {
        let lexicon = try WordLexicon(frequencies: [FixtureLayouts.ruSourceID: ["привет": 100]])

        let decision = Detector.decide(
            token: TypedToken(text: "GHBDTN", sourceID: FixtureLayouts.usSourceID, strokes: [
                FixtureLayouts.shiftedG,
                FixtureLayouts.h,
                FixtureLayouts.b,
                FixtureLayouts.d,
                FixtureLayouts.t,
                FixtureLayouts.n
            ]),
            source: FixtureLayouts.us,
            target: FixtureLayouts.ru,
            surface: .plainText,
            exceptions: WordExceptions(words: ["ghbdtn"]),
            lexicon: lexicon
        )

        XCTAssertEqual(decision, .abstain(.explicitException))
    }

    func testAbstainsOnAnUnverifiedSurface() throws {
        let lexicon = try WordLexicon(frequencies: [FixtureLayouts.ruSourceID: ["привет": 100]])

        XCTAssertEqual(
            Detector.decide(
                token: TypedToken(text: "ghbdtn", sourceID: FixtureLayouts.usSourceID, strokes: FixtureLayouts.wordStrokes),
                source: FixtureLayouts.us,
                target: FixtureLayouts.ru,
                surface: .unknown,
                exceptions: WordExceptions(),
                lexicon: lexicon
            ),
            .abstain(.unsupportedSurface)
        )
    }

    func testRejectsAWordProtectedByItsShapeEvenWhenAConversionWouldBeTempting() throws {
        let lexicon = try WordLexicon(frequencies: [FixtureLayouts.ruSourceID: ["привет": 100]])
        for tokenText in ["ghbdtn.com", "gh_b_d_t_n", "ghb123dtn", "GHBDTN"] {
            let token = TypedToken(text: tokenText, sourceID: FixtureLayouts.usSourceID, strokes: FixtureLayouts.wordStrokes)
            XCTAssertEqual(
                Detector.decide(
                    token: token,
                    source: FixtureLayouts.us,
                    target: FixtureLayouts.ru,
                    surface: .plainText,
                    exceptions: WordExceptions(),
                    lexicon: lexicon
                ),
                .abstain(.protectedToken),
                "Should protect \(tokenText)"
            )
        }
    }

    func testAllowsPunctuationWhenConfirmedStrokeMapsItToTargetLetter() throws {
        let v = KeyStroke(keyCode: 201)
        let j = KeyStroke(keyCode: 202)
        let semicolon = KeyStroke(keyCode: 203)
        let y = KeyStroke(keyCode: 204)
        let source = try LayoutProfile(
            sourceID: "fixture.us.punctuation",
            outputs: [v: "v", j: "j", semicolon: ";", y: "y"]
        )
        let target = try LayoutProfile(
            sourceID: "fixture.ru.punctuation",
            outputs: [v: "м", j: "о", semicolon: "ж", y: "н"]
        )
        let token = TypedToken(
            text: "vj;yj",
            sourceID: source.sourceID,
            strokes: [v, j, semicolon, y, j]
        )
        let lexicon = try WordLexicon(frequencies: [target.sourceID: ["можно": 41]])

        XCTAssertEqual(
            Detector.decide(
                token: token,
                source: source,
                target: target,
                surface: .plainText,
                exceptions: WordExceptions(),
                lexicon: lexicon
            ),
            .suggestion(CorrectionCandidate(
                original: "vj;yj",
                replacement: "можно",
                targetSourceID: target.sourceID
            ))
        )
    }

    func testAllowsSourceDotAndCommaWhenConfirmedMappingsFormALetterWord() throws {
        XCTAssertEqual(
            try decideMappedToken("k.,jdm", convertsTo: "любовь"),
            .suggestion(CorrectionCandidate(
                original: "k.,jdm",
                replacement: "любовь",
                targetSourceID: "fixture.target.k.,jdm"
            ))
        )
    }

    func testAllowsConfirmedBacktickMappingToTheRussianYoLetter() throws {
        XCTAssertEqual(
            try decideMappedToken("`krf", convertsTo: "ёлка"),
            .suggestion(CorrectionCandidate(
                original: "`krf",
                replacement: "ёлка",
                targetSourceID: "fixture.target.`krf"
            ))
        )
    }

    func testAllowsTwoSourcePunctuationKeysWhenTheyCompleteFourTargetLetters() throws {
        XCTAssertEqual(
            try decideMappedToken(",.hj", convertsTo: "бюро"),
            .suggestion(CorrectionCandidate(
                original: ",.hj",
                replacement: "бюро",
                targetSourceID: "fixture.target.,.hj"
            ))
        )
    }

    func testAllowsOneSourceLetterWhenConfirmedMappingsFormThreeTargetLetters() throws {
        XCTAssertEqual(
            try decideMappedToken(",m.", convertsTo: "бью"),
            .suggestion(CorrectionCandidate(
                original: ",m.",
                replacement: "бью",
                targetSourceID: "fixture.target.,m."
            ))
        )
    }

    func testUnderscoreRemainsProtectedEvenWhenItMapsToATargetLetter() throws {
        XCTAssertEqual(
            try decideMappedToken("ab_cd", convertsTo: "снегу"),
            .abstain(.protectedToken)
        )
    }

    func testDomainRemainsProtectedWhenItsDotMapsToATargetLetter() throws {
        XCTAssertEqual(
            try decideMappedToken("example.com", convertsTo: "приветмирок"),
            .abstain(.protectedToken)
        )
    }

    func testAbstainsForMismatchedStrokesUnknownSourceAndNonLetterCandidate() throws {
        let lexicon = try WordLexicon(frequencies: [FixtureLayouts.ruSourceID: ["привет": 100]])
        let mismatched = TypedToken(
            text: "other",
            sourceID: FixtureLayouts.usSourceID,
            strokes: FixtureLayouts.wordStrokes
        )
        XCTAssertEqual(
            Detector.decide(
                token: mismatched,
                source: FixtureLayouts.us,
                target: FixtureLayouts.ru,
                surface: .plainText,
                exceptions: WordExceptions(),
                lexicon: lexicon
            ),
            .abstain(.conversionUnavailable)
        )

        let unknownSource = TypedToken(
            text: "ghbdtn",
            sourceID: "fixture.unknown",
            strokes: FixtureLayouts.wordStrokes
        )
        XCTAssertEqual(
            Detector.decide(
                token: unknownSource,
                source: FixtureLayouts.us,
                target: FixtureLayouts.ru,
                surface: .plainText,
                exceptions: WordExceptions(),
                lexicon: lexicon
            ),
            .abstain(.conversionUnavailable)
        )

        let punctuationTarget = try LayoutProfile(
            sourceID: "fixture.ru.punctuation-output",
            outputs: Dictionary(uniqueKeysWithValues: zip(FixtureLayouts.wordStrokes, ["п", "р", "и", "в", "!", "т"]))
        )
        XCTAssertEqual(
            Detector.decide(
                token: TypedToken(text: "ghbdtn", sourceID: FixtureLayouts.usSourceID, strokes: FixtureLayouts.wordStrokes),
                source: FixtureLayouts.us,
                target: punctuationTarget,
                surface: .plainText,
                exceptions: WordExceptions(),
                lexicon: try WordLexicon(frequencies: [punctuationTarget.sourceID: ["прив!т": 1]])
            ),
            .abstain(.protectedToken)
        )
    }

    func testAbstainsWhenConvertedCandidateIsTheOriginalWord() throws {
        let sameLettersTarget = try LayoutProfile(
            sourceID: "fixture.us.same-output",
            outputs: [
                FixtureLayouts.g: "g",
                FixtureLayouts.h: "h",
                FixtureLayouts.b: "b",
                FixtureLayouts.d: "d",
                FixtureLayouts.t: "t",
                FixtureLayouts.n: "n"
            ]
        )
        let lexicon = try WordLexicon(frequencies: [:])

        XCTAssertEqual(
            Detector.decide(
                token: TypedToken(
                    text: "ghbdtn",
                    sourceID: FixtureLayouts.usSourceID,
                    strokes: FixtureLayouts.wordStrokes
                ),
                source: FixtureLayouts.us,
                target: sameLettersTarget,
                surface: .plainText,
                exceptions: WordExceptions(),
                lexicon: lexicon
            ),
            .abstain(.unchangedCandidate)
        )
    }

    func testWordLexiconRejectsEmptySourceIDsAndNonpositiveFrequencies() {
        XCTAssertThrowsError(try WordLexicon(frequencies: ["  ": ["hello": 1]]))
        XCTAssertThrowsError(try WordLexicon(frequencies: ["fixture.us": ["hello": 0]]))
        XCTAssertThrowsError(try WordLexicon(frequencies: ["fixture.us": ["hello": -1]]))
    }

    func testWordLexiconMatchesCanonicalCaseInsensitiveWordsPerSource() throws {
        let lexicon = try WordLexicon(frequencies: ["fixture.us": ["Café": 5]])

        XCTAssertTrue(lexicon.contains("CAFÉ", sourceID: "fixture.us"))
        XCTAssertTrue(lexicon.contains("Cafe\u{301}", sourceID: "fixture.us"))
        XCTAssertFalse(lexicon.contains("Cafe", sourceID: "fixture.us"))
        XCTAssertFalse(lexicon.contains("CAFÉ", sourceID: "fixture.other"))
    }

    private func decide(_ text: String, sourceID: String, lexicon: WordLexicon) -> DetectionDecision {
        Detector.decide(
            token: TypedToken(text: text, sourceID: sourceID, strokes: FixtureLayouts.wordStrokes),
            source: FixtureLayouts.us,
            target: FixtureLayouts.ru,
            surface: .plainText,
            exceptions: WordExceptions(),
            lexicon: lexicon
        )
    }

    private func decideMappedToken(_ sourceText: String, convertsTo targetText: String) throws -> DetectionDecision {
        let strokes = (0..<sourceText.count).map { KeyStroke(keyCode: UInt16(300 + $0)) }
        let sourceID = "fixture.source.\(sourceText)"
        let targetID = "fixture.target.\(sourceText)"
        let sourceOutputs = Dictionary(uniqueKeysWithValues: zip(strokes, sourceText.map { String($0) }))
        let targetOutputs = Dictionary(uniqueKeysWithValues: zip(strokes, targetText.map { String($0) }))
        let source = try LayoutProfile(sourceID: sourceID, outputs: sourceOutputs)
        let target = try LayoutProfile(sourceID: targetID, outputs: targetOutputs)
        let token = TypedToken(text: sourceText, sourceID: sourceID, strokes: strokes)
        let lexicon = try WordLexicon(frequencies: [targetID: [targetText: 1]])

        return Detector.decide(
            token: token,
            source: source,
            target: target,
            surface: .plainText,
            exceptions: WordExceptions(),
            lexicon: lexicon
        )
    }
}
