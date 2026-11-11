import Foundation

/// Rejects records that could make the baseline appear better by omission or leakage.
public enum CorpusValidator {
    public static func validate(
        tuning: [CorpusExample],
        heldOut: [CorpusExample],
        layouts: [String: LayoutProfile],
        lexiconFrequencies: [String: [String: Int]]
    ) throws {
        guard !tuning.isEmpty else { throw EvaluationDataError.emptyCorpus(split: "tuning") }
        guard !heldOut.isEmpty else { throw EvaluationDataError.emptyCorpus(split: "held-out") }
        guard layouts.count >= 2,
              layouts.allSatisfy({ $0.key == $0.value.sourceID }) else {
            throw EvaluationDataError.invalidLayouts("at least two unique source IDs are required")
        }

        try validateLexicon(lexiconFrequencies, layouts: layouts)

        let rows: [(CorpusExample, String)] = tuning.map { ($0, "tuning") } + heldOut.map { ($0, "held-out") }
        var ids: Set<String> = []
        var groupsBySplit: [String: String] = [:]
        var formsBySplit: [String: String] = [:]
        var layoutFormsBySplit: [String: String] = [:]
        var pairsBySplit: [String: String] = [:]

        for (example, expectedSplit) in rows {
            guard !ids.contains(example.id) else {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "duplicate ID")
            }
            ids.insert(example.id)

            for (name, value) in [("id", example.id), ("groupID", example.groupID), ("category", example.category), ("split", example.split),
                                  ("text", example.text), ("sourceID", example.sourceID), ("targetSourceID", example.targetSourceID)] {
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw EvaluationDataError.invalidRecord(id: example.id, reason: "\(name) must not be empty")
                }
            }
            guard example.split == expectedSplit else {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "split must match its JSONL file")
            }
            guard example.sourceID != example.targetSourceID else {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "source and target IDs must differ")
            }
            guard let source = layouts[example.sourceID] else {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "unknown source ID \(example.sourceID)")
            }
            guard let target = layouts[example.targetSourceID] else {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "unknown target source ID \(example.targetSourceID)")
            }
            guard TokenProtection.isWithinRuntimeLimits(example.text),
                  !example.text.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }) else {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "text must be one token within core limits")
            }
            if let expectedText = example.expectedText {
                guard !expectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !expectedText.utf16.elementsEqual(example.text.utf16),
                      TokenProtection.isWithinRuntimeLimits(expectedText),
                      !expectedText.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }),
                      TokenProtection.isAllLetters(expectedText) else {
                    throw EvaluationDataError.invalidRecord(id: example.id, reason: "error expectation must be a distinct letter token")
                }
                guard example.surface == .plainText else {
                    throw EvaluationDataError.invalidRecord(id: example.id, reason: "errors require a plain-text surface")
                }
            }

            let groupKey = normalizedForm(example.groupID)
            if let otherSplit = groupsBySplit[groupKey], otherSplit != expectedSplit {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "groupID leaks across tuning and held-out splits")
            }
            groupsBySplit[groupKey] = expectedSplit

            let targetText: String?
            if example.provenanceAvailable {
                targetText = try validatePhysicalTrace(example, source: source, target: target)
            } else {
                guard example.expectedText == nil, example.strokes.isEmpty else {
                    throw EvaluationDataError.invalidRecord(id: example.id, reason: "missing provenance is allowed only for preserves with empty strokes")
                }
                targetText = nil
            }

            let sourceForm = normalizedForm(example.text)
            try registerPhysicalForm(sourceForm, id: example.id, split: expectedSplit, formsBySplit: &formsBySplit)
            try registerPhysicalForm(
                "\(example.sourceID)\u{1F}\(sourceForm)",
                id: example.id,
                split: expectedSplit,
                formsBySplit: &layoutFormsBySplit
            )
            if let targetText {
                let targetForm = normalizedForm(targetText)
                try registerPhysicalForm(targetForm, id: example.id, split: expectedSplit, formsBySplit: &formsBySplit)
                try registerPhysicalForm(
                    "\(example.targetSourceID)\u{1F}\(targetForm)",
                    id: example.id,
                    split: expectedSplit,
                    formsBySplit: &layoutFormsBySplit
                )
                let pair = ["\(example.sourceID):\(sourceForm)", "\(example.targetSourceID):\(targetForm)"].sorted().joined(separator: "\u{1F}")
                if let otherSplit = pairsBySplit[pair], otherSplit != expectedSplit {
                    throw EvaluationDataError.invalidRecord(id: example.id, reason: "physically corresponding forms leak across splits")
                }
                pairsBySplit[pair] = expectedSplit
            }
        }
    }

    private static func validatePhysicalTrace(
        _ example: CorpusExample,
        source: LayoutProfile,
        target: LayoutProfile
    ) throws -> String {
        guard !example.strokes.isEmpty,
              example.strokes.count <= CoreLimits.maximumTokenStrokes else {
            throw EvaluationDataError.invalidRecord(id: example.id, reason: "provenance requires 1...64 physical strokes")
        }

        var sourceUTF16: [UInt16] = []
        var targetText = ""
        var scalarCount = 0
        for stroke in example.strokes {
            guard !stroke.modifiers.hasUnknownBits,
                  !stroke.modifiers.contains(.command),
                  !stroke.modifiers.contains(.control),
                  let sourceOutput = source.outputs[stroke],
                  let targetOutput = target.outputs[stroke] else {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "stroke has an unsupported modifier or missing layout output")
            }
            scalarCount += sourceOutput.unicodeScalars.count
            guard scalarCount <= CoreLimits.maximumContextScalars else {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "physical trace exceeds core scalar limits")
            }
            sourceUTF16.append(contentsOf: sourceOutput.utf16)
            targetText.append(contentsOf: targetOutput)
        }
        guard sourceUTF16.elementsEqual(example.text.utf16) else {
            throw EvaluationDataError.invalidRecord(id: example.id, reason: "source outputs do not exactly match text")
        }
        if let expectedText = example.expectedText,
           !targetText.utf16.elementsEqual(expectedText.utf16) {
            throw EvaluationDataError.invalidRecord(id: example.id, reason: "expectedText does not match target outputs for the physical trace")
        }
        return targetText
    }

    private static func validateLexicon(
        _ frequencies: [String: [String: Int]],
        layouts: [String: LayoutProfile]
    ) throws {
        guard !frequencies.isEmpty else {
            throw EvaluationDataError.invalidLexicon("at least one source dictionary is required")
        }
        var wordCount = 0
        for (sourceID, words) in frequencies {
            guard !sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  layouts[sourceID] != nil else {
                throw EvaluationDataError.invalidLexicon("unknown or empty source ID \(sourceID)")
            }
            var normalizedWords: Set<String> = []
            for (word, frequency) in words {
                guard !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      TokenProtection.isWithinRuntimeLimits(word),
                      TokenProtection.isAllLetters(word) else {
                    throw EvaluationDataError.invalidLexicon("invalid word key for \(sourceID)")
                }
                guard frequency > 0 else {
                    throw EvaluationDataError.invalidLexicon("frequency for \(word) must be positive")
                }
                let normalized = WordNormalization.key(for: word)
                guard normalizedWords.insert(normalized).inserted else {
                    throw EvaluationDataError.invalidLexicon("duplicate normalized word key \(word) for \(sourceID)")
                }
                wordCount += 1
            }
        }
        guard wordCount > 0 else {
            throw EvaluationDataError.invalidLexicon("at least one word is required")
        }
    }

    private static func registerPhysicalForm(
        _ form: String,
        id: String,
        split: String,
        formsBySplit: inout [String: String]
    ) throws {
        if let otherSplit = formsBySplit[form], otherSplit != split {
            throw EvaluationDataError.invalidRecord(id: id, reason: "normalized lexical form leaks across tuning and held-out splits")
        }
        formsBySplit[form] = split
    }

    private static func normalizedForm(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .precomposedStringWithCanonicalMapping
    }
}
