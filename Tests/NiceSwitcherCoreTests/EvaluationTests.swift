import Foundation
import XCTest
@testable import NiceSwitcherCore

final class EvaluationTests: XCTestCase {
    func testCorpusExampleCodableRoundTripsRequiredNullAndErrorLabels() throws {
        let preserve = example(id: "preserve", group: "g1", category: "names", text: "Tim", expected: nil, provenance: false, strokes: [])
        let encodedPreserve = try JSONEncoder().encode(preserve)
        let preserveObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedPreserve) as? [String: Any])
        XCTAssertTrue(preserveObject["expectedText"] is NSNull)
        XCTAssertEqual(try JSONDecoder().decode(CorpusExample.self, from: encodedPreserve), preserve)

        let error = example(id: "error", group: "g2", category: "errors", text: "abc", expected: "дом", provenance: true, strokes: abcStrokes)
        let encodedError = try JSONEncoder().encode(error)
        XCTAssertEqual(try JSONDecoder().decode(CorpusExample.self, from: encodedError), error)
    }

    func testKeyStrokeCodablePreservesKnownModifiersAndRejectsUnknownBits() throws {
        let known = KeyStroke(keyCode: 17, modifiers: [.shift, .option])
        XCTAssertEqual(try JSONDecoder().decode(KeyStroke.self, from: JSONEncoder().encode(known)), known)

        let unknown = KeyStroke(keyCode: 17, modifiers: KeyModifiers(rawValue: 0x80))
        XCTAssertThrowsError(try JSONEncoder().encode(unknown))
    }

    func testSummaryAccountsForPreservesCorrectWrongMissedAndAbstentions() throws {
        let examples = [
            example(id: "preserve-no-provenance", group: "g1", category: "mixed", text: "ruEN", expected: nil, provenance: false, strokes: []),
            example(id: "preserve-name", group: "g2", category: "names", text: "Tim", expected: nil, provenance: true, strokes: timStrokes),
            example(id: "correct-error", group: "g3", category: "errors", text: "abc", expected: "дом", provenance: true, strokes: abcStrokes),
            example(id: "missed-error", group: "g4", category: "errors", text: "abc", expected: "дом", provenance: true, strokes: abcStrokes),
            example(id: "wrong-error", group: "g5", category: "errors", text: "abc", expected: "дома", provenance: true, strokes: abcStrokes)
        ]
        let predictions: [EvaluationPrediction] = [
            .abstain,
            .suggestion("Ешь"),
            .suggestion("дом"),
            .abstain,
            .suggestion("дом")
        ]

        let summary = try EvaluationSummary.summarizing(examples: examples, predictions: predictions)

        XCTAssertEqual(summary.total, 5)
        XCTAssertEqual(summary.correctTokens, 2)
        XCTAssertEqual(summary.errorTokens, 3)
        XCTAssertEqual(summary.falseCorrections, 1)
        XCTAssertEqual(summary.correctedErrors, 1)
        XCTAssertEqual(summary.missedErrors, 1)
        XCTAssertEqual(summary.wrongCorrections, 1)
        XCTAssertEqual(summary.abstentions, 2)
        XCTAssertEqual(summary.falseCorrectionRate, 0.5)
        XCTAssertEqual(summary.supportedErrorRecall ?? -1, 1.0 / 3.0, accuracy: 0.000001)
        XCTAssertEqual(summary.correctedErrors + summary.missedErrors + summary.wrongCorrections, summary.errorTokens)
        XCTAssertEqual(summary.categoryCounts["errors"]?.total, 3)
        XCTAssertEqual(summary.categoryCounts["errors"]?.wrongCorrections, 1)
        XCTAssertEqual(summary.categoryCounts["names"]?.falseCorrections, 1)
    }

    func testEmptyEvaluationFailsAndMissingClassRateIsNull() throws {
        XCTAssertThrowsError(try EvaluationSummary.summarizing(examples: [], predictions: []))

        let onlyPreserve = [
            example(id: "preserve", group: "g1", category: "names", text: "Tim", expected: nil, provenance: false, strokes: [])
        ]
        let preserveSummary = try EvaluationSummary.summarizing(examples: onlyPreserve, predictions: [.abstain])
        XCTAssertNil(preserveSummary.supportedErrorRecall)
        XCTAssertNil(preserveSummary.categoryCounts["names"]?.supportedErrorRecall)
        XCTAssertEqual(preserveSummary.falseCorrectionRate, 0)

        let onlyError = [
            example(id: "error", group: "g2", category: "errors", text: "abc", expected: "дом", provenance: true, strokes: abcStrokes)
        ]
        let errorSummary = try EvaluationSummary.summarizing(examples: onlyError, predictions: [.abstain])
        XCTAssertNil(errorSummary.falseCorrectionRate)
        XCTAssertNil(errorSummary.categoryCounts["errors"]?.falseCorrectionRate)
        XCTAssertEqual(errorSummary.supportedErrorRecall, 0)
        let encoded = try JSONEncoder().encode(errorSummary)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertTrue(object["falseCorrectionRate"] is NSNull)
        let categories = try XCTUnwrap(object["categoryCounts"] as? [String: [String: Any]])
        XCTAssertTrue(categories["errors"]?["falseCorrectionRate"] is NSNull)
    }

    func testLoaderRequiresExpectedTextKeyEvenWhenNullMeansPreserve() throws {
        let directory = try makeDataDirectory(
            tuning: [corpusLine(id: "missing-label", group: "g1", split: "tuning", text: "Tim", expectedText: nil, includeExpectedText: false, provenanceAvailable: false, strokes: [])],
            heldOut: [corpusLine(id: "valid-preserve", group: "g2", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: directory))
    }

    func testLoaderRejectsMalformedMiddleRowInsteadOfSkippingIt() throws {
        let validFirst = corpusLine(id: "valid-first", group: "g1", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: true, strokes: abcStrokes)
        let validLast = corpusLine(id: "valid-last", group: "g2", split: "tuning", text: "Tim", expectedText: nil, provenanceAvailable: false, strokes: [])
        let held = corpusLine(id: "valid-held", group: "g3", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])
        let directory = try makeDataDirectory(tuning: [validFirst, "{ malformed JSONL", validLast], heldOut: [held])
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: directory))

        let blankDirectory = try makeDataDirectory(tuning: [validFirst, "", validLast], heldOut: [held])
        defer { try? FileManager.default.removeItem(at: blankDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: blankDirectory))
    }

    func testValidDatasetUsesDetectorForCorrectErrorAndHardNegativeName() throws {
        let directory = try makeDataDirectory(
            tuning: [corpusLine(id: "tuning-error", group: "g1", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: true, strokes: abcStrokes)],
            heldOut: [corpusLine(id: "held-name", group: "g2", split: "held-out", text: "Tim", expectedText: nil, provenanceAvailable: true, strokes: timStrokes)]
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let dataset = try EvaluationDataset.load(dataDirectory: directory)
        let tuning = try dataset.tuningSummary()
        let heldOut = try dataset.heldOutSummary()

        XCTAssertEqual(tuning.total, 1)
        XCTAssertEqual(tuning.correctedErrors, 1)
        XCTAssertEqual(tuning.errorTokens, 1)
        XCTAssertEqual(heldOut.total, 1)
        XCTAssertEqual(heldOut.correctTokens, 1)
        XCTAssertEqual(heldOut.falseCorrections, 1)
        XCTAssertEqual(heldOut.categoryCounts["fixture"]?.falseCorrections, 1)
    }

    func testValidatorRejectsDuplicateIDsAcrossSplits() throws {
        let directory = try makeDataDirectory(
            tuning: [corpusLine(id: "same-id", group: "g1", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: true, strokes: abcStrokes)],
            heldOut: [corpusLine(id: "same-id", group: "g2", split: "held-out", text: "Tim", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: directory))
    }

    func testValidatorRejectsGroupLeakageAcrossSplits() throws {
        let directory = try makeDataDirectory(
            tuning: [corpusLine(id: "tuning-row", group: "same-group", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: true, strokes: abcStrokes)],
            heldOut: [corpusLine(id: "held-row", group: "same-group", split: "held-out", text: "Tim", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: directory))
    }

    func testValidatorCatchesPhysicalFormLeakAfterGroupRename() throws {
        let directory = try makeDataDirectory(
            tuning: [corpusLine(id: "tuning-row", group: "first-name", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: true, strokes: abcStrokes)],
            heldOut: [corpusLine(id: "held-row", group: "different-name", split: "held-out", text: "дом", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: directory))
    }

    func testValidatorRejectsInvalidProvenanceAndMismatchedPhysicalText() throws {
        let missingStrokeDirectory = try makeDataDirectory(
            tuning: [corpusLine(id: "missing-strokes", group: "g1", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: true, strokes: [])],
            heldOut: [corpusLine(id: "held-row", group: "g2", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: missingStrokeDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: missingStrokeDirectory))

        let mismatchDirectory = try makeDataDirectory(
            tuning: [corpusLine(id: "mismatch", group: "g3", split: "tuning", text: "wrong", expectedText: "дом", provenanceAvailable: true, strokes: abcStrokes)],
            heldOut: [corpusLine(id: "held-row-2", group: "g4", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: mismatchDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: mismatchDirectory))

        let expectationDirectory = try makeDataDirectory(
            tuning: [corpusLine(id: "wrong-expectation", group: "g7", split: "tuning", text: "abc", expectedText: "дома", provenanceAvailable: true, strokes: abcStrokes)],
            heldOut: [corpusLine(id: "held-row-4", group: "g8", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: expectationDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: expectationDirectory))

        let missingKeyDirectory = try makeDataDirectory(
            tuning: [corpusLine(id: "missing-key", group: "g9", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: true, strokes: [KeyStroke(keyCode: 999)])],
            heldOut: [corpusLine(id: "held-row-5", group: "g10", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: missingKeyDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: missingKeyDirectory))
    }

    func testValidatorRejectsBlankIDsUnknownSourcesAndFalseProvenanceErrors() throws {
        let blankIDDirectory = try makeDataDirectory(
            tuning: [corpusLine(id: " ", group: "g1", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: true, strokes: abcStrokes)],
            heldOut: [corpusLine(id: "held-row", group: "g2", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: blankIDDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: blankIDDirectory))

        let unknownSourceDirectory = try makeDataDirectory(
            tuning: [corpusLine(id: "unknown-source", group: "g3", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: true, strokes: abcStrokes, sourceID: "fixture.missing")],
            heldOut: [corpusLine(id: "held-row-2", group: "g4", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: unknownSourceDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: unknownSourceDirectory))

        let missingProvenanceDirectory = try makeDataDirectory(
            tuning: [corpusLine(id: "error-without-provenance", group: "g5", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: false, strokes: [])],
            heldOut: [corpusLine(id: "held-row-3", group: "g6", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: missingProvenanceDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: missingProvenanceDirectory))

        let falseProvenanceDirectory = try makeDataDirectory(
            tuning: [corpusLine(id: "strokes-without-provenance", group: "g11", split: "tuning", text: "abc", expectedText: nil, provenanceAvailable: false, strokes: abcStrokes)],
            heldOut: [corpusLine(id: "held-row-6", group: "g12", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: falseProvenanceDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: falseProvenanceDirectory))
    }

    func testValidatorRejectsNonpositiveLexiconFrequency() throws {
        let directory = try makeDataDirectory(
            tuning: [corpusLine(id: "tuning-row", group: "g1", split: "tuning", text: "abc", expectedText: "дом", provenanceAvailable: true, strokes: abcStrokes)],
            heldOut: [corpusLine(id: "held-row", group: "g2", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])],
            baselineLexicon: #"{"frequencies":{"fixture.us":{"the":1},"fixture.ru":{"дом":0}}}"#
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: directory))
    }

    func testLoaderRejectsEmptySplitAndEmptyTextMetadata() throws {
        let emptySplitDirectory = try makeDataDirectory(
            tuning: [],
            heldOut: [corpusLine(id: "held", group: "g1", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: emptySplitDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: emptySplitDirectory))

        let emptyTextDirectory = try makeDataDirectory(
            tuning: [corpusLine(id: "blank-text", group: "g2", split: "tuning", text: "", expectedText: nil, provenanceAvailable: false, strokes: [])],
            heldOut: [corpusLine(id: "held-2", group: "g3", split: "held-out", text: "ruEN", expectedText: nil, provenanceAvailable: false, strokes: [])]
        )
        defer { try? FileManager.default.removeItem(at: emptyTextDirectory) }
        XCTAssertThrowsError(try EvaluationDataset.load(dataDirectory: emptyTextDirectory))
    }

    private var abcStrokes: [KeyStroke] {
        [KeyStroke(keyCode: 0), KeyStroke(keyCode: 1), KeyStroke(keyCode: 2)]
    }

    private var timStrokes: [KeyStroke] {
        [KeyStroke(keyCode: 17, modifiers: .shift), KeyStroke(keyCode: 34), KeyStroke(keyCode: 46)]
    }

    private func example(
        id: String,
        group: String,
        category: String,
        text: String,
        expected: String?,
        provenance: Bool,
        strokes: [KeyStroke]
    ) -> CorpusExample {
        CorpusExample(
            id: id,
            groupID: group,
            category: category,
            split: "held-out",
            text: text,
            expectedText: expected,
            sourceID: "fixture.us",
            targetSourceID: "fixture.ru",
            surface: .plainText,
            provenanceAvailable: provenance,
            strokes: strokes
        )
    }

    private func corpusLine(
        id: String,
        group: String,
        split: String,
        text: String,
        expectedText: String?,
        includeExpectedText: Bool = true,
        provenanceAvailable: Bool,
        strokes: [KeyStroke],
        sourceID: String = "fixture.us"
    ) -> String {
        let record = TestCorpusLine(
            id: id,
            groupID: group,
            category: "fixture",
            split: split,
            text: text,
            expectedText: expectedText,
            includeExpectedText: includeExpectedText,
            sourceID: sourceID,
            targetSourceID: "fixture.ru",
            surface: "plainText",
            provenanceAvailable: provenanceAvailable,
            strokes: strokes.map { TestStroke(keyCode: $0.keyCode, modifiers: $0.modifiers.contains(.shift) ? ["shift"] : []) }
        )
        let data = try! JSONEncoder().encode(record)
        return String(decoding: data, as: UTF8.self)
    }

    private func makeDataDirectory(tuning: [String], heldOut: [String], baselineLexicon: String? = nil) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("NiceSwitcherEvaluationTests-\(UUID().uuidString)")
        let corpusDirectory = root.appendingPathComponent("Corpus")
        let layoutsDirectory = root.appendingPathComponent("Layouts")
        let lexiconDirectory = root.appendingPathComponent("Lexicon")
        try FileManager.default.createDirectory(at: corpusDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: layoutsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: lexiconDirectory, withIntermediateDirectories: true)
        try (tuning.joined(separator: "\n") + "\n").write(to: corpusDirectory.appendingPathComponent("tuning.jsonl"), atomically: true, encoding: .utf8)
        try (heldOut.joined(separator: "\n") + "\n").write(to: corpusDirectory.appendingPathComponent("held-out.jsonl"), atomically: true, encoding: .utf8)
        try Self.layoutJSON.write(to: layoutsDirectory.appendingPathComponent("fixtures.json"), atomically: true, encoding: .utf8)
        try (baselineLexicon ?? Self.lexiconJSON).write(to: lexiconDirectory.appendingPathComponent("baseline.json"), atomically: true, encoding: .utf8)
        return root
    }

    private static let layoutJSON = #"{"layouts":[{"sourceID":"fixture.us","entries":[{"keyCode":0,"modifiers":[],"text":"a"},{"keyCode":1,"modifiers":[],"text":"b"},{"keyCode":2,"modifiers":[],"text":"c"},{"keyCode":17,"modifiers":[],"text":"t"},{"keyCode":17,"modifiers":["shift"],"text":"T"},{"keyCode":34,"modifiers":[],"text":"i"},{"keyCode":46,"modifiers":[],"text":"m"}]},{"sourceID":"fixture.ru","entries":[{"keyCode":0,"modifiers":[],"text":"д"},{"keyCode":1,"modifiers":[],"text":"о"},{"keyCode":2,"modifiers":[],"text":"м"},{"keyCode":17,"modifiers":[],"text":"е"},{"keyCode":17,"modifiers":["shift"],"text":"Е"},{"keyCode":34,"modifiers":[],"text":"ш"},{"keyCode":46,"modifiers":[],"text":"ь"}]}]}"#
    private static let lexiconJSON = #"{"frequencies":{"fixture.us":{"the":100},"fixture.ru":{"дом":100,"ешь":80}}}"#
}

private struct TestCorpusLine: Encodable {
    let id: String
    let groupID: String
    let category: String
    let split: String
    let text: String
    let expectedText: String?
    let includeExpectedText: Bool
    let sourceID: String
    let targetSourceID: String
    let surface: String
    let provenanceAvailable: Bool
    let strokes: [TestStroke]

    enum CodingKeys: String, CodingKey {
        case id, groupID, category, split, text, expectedText, sourceID, targetSourceID, surface, provenanceAvailable, strokes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(groupID, forKey: .groupID)
        try container.encode(category, forKey: .category)
        try container.encode(split, forKey: .split)
        try container.encode(text, forKey: .text)
        if includeExpectedText {
            if let expectedText {
                try container.encode(expectedText, forKey: .expectedText)
            } else {
                try container.encodeNil(forKey: .expectedText)
            }
        }
        try container.encode(sourceID, forKey: .sourceID)
        try container.encode(targetSourceID, forKey: .targetSourceID)
        try container.encode(surface, forKey: .surface)
        try container.encode(provenanceAvailable, forKey: .provenanceAvailable)
        try container.encode(strokes, forKey: .strokes)
    }
}

private struct TestStroke: Encodable {
    let keyCode: UInt16
    let modifiers: [String]
}
