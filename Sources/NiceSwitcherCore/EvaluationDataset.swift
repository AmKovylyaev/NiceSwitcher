import Foundation

public struct EvaluationDataset: Sendable {
    public let tuningExamples: [CorpusExample]
    public let heldOutExamples: [CorpusExample]
    public let layouts: [String: LayoutProfile]
    public let lexicon: WordLexicon

    private init(
        tuningExamples: [CorpusExample],
        heldOutExamples: [CorpusExample],
        layouts: [String: LayoutProfile],
        lexicon: WordLexicon
    ) {
        self.tuningExamples = tuningExamples
        self.heldOutExamples = heldOutExamples
        self.layouts = layouts
        self.lexicon = lexicon
    }

    public static func load(dataDirectory: URL) throws -> EvaluationDataset {
        let corpusDirectory = dataDirectory.appendingPathComponent("Corpus", isDirectory: true)
        let layoutURL = dataDirectory.appendingPathComponent("Layouts/fixtures.json")
        let lexiconURL = dataDirectory.appendingPathComponent("Lexicon/baseline.json")

        let tuningExamples = try loadJSONLines(
            at: corpusDirectory.appendingPathComponent("tuning.jsonl"),
            expectedSplit: "tuning"
        )
        let heldOutExamples = try loadJSONLines(
            at: corpusDirectory.appendingPathComponent("held-out.jsonl"),
            expectedSplit: "held-out"
        )
        let layouts = try loadLayouts(at: layoutURL)
        let lexiconFrequencies = try loadLexicon(at: lexiconURL)

        try CorpusValidator.validate(
            tuning: tuningExamples,
            heldOut: heldOutExamples,
            layouts: layouts,
            lexiconFrequencies: lexiconFrequencies
        )
        let lexicon: WordLexicon
        do {
            lexicon = try WordLexicon(frequencies: lexiconFrequencies)
        } catch {
            throw EvaluationDataError.invalidLexicon(error.localizedDescription)
        }

        return EvaluationDataset(
            tuningExamples: tuningExamples,
            heldOutExamples: heldOutExamples,
            layouts: layouts,
            lexicon: lexicon
        )
    }

    public func tuningSummary() throws -> EvaluationSummary {
        try evaluate(tuningExamples)
    }

    public func heldOutSummary() throws -> EvaluationSummary {
        try evaluate(heldOutExamples)
    }

    func evaluate(_ examples: [CorpusExample]) throws -> EvaluationSummary {
        guard !examples.isEmpty else { throw EvaluationDataError.emptyEvaluation }

        let predictions = try examples.map { example -> EvaluationPrediction in
            guard let source = layouts[example.sourceID],
                  let target = layouts[example.targetSourceID] else {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "layout profile is unavailable")
            }
            let token = TypedToken(text: example.text, sourceID: example.sourceID, strokes: example.strokes)
            switch Detector.decide(
                token: token,
                source: source,
                target: target,
                surface: example.surface,
                exceptions: WordExceptions(),
                lexicon: lexicon
            ) {
            case .suggestion(let candidate):
                return .suggestion(candidate.replacement)
            case .abstain:
                return .abstain
            }
        }
        return try EvaluationSummary.summarizing(examples: examples, predictions: predictions)
    }

    private static func loadJSONLines(at url: URL, expectedSplit: String) throws -> [CorpusExample] {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else {
            throw EvaluationDataError.missingFile(path)
        }

        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw EvaluationDataError.invalidFile(path: path, reason: error.localizedDescription)
        }

        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" { lines.removeLast() }
        guard !lines.isEmpty else { throw EvaluationDataError.emptyCorpus(split: expectedSplit) }

        let decoder = JSONDecoder()
        var examples: [CorpusExample] = []
        examples.reserveCapacity(lines.count)
        for (offset, untrimmedLine) in lines.enumerated() {
            let line = untrimmedLine.hasSuffix("\r") ? String(untrimmedLine.dropLast()) : untrimmedLine
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw EvaluationDataError.invalidJSONLine(path: path, line: offset + 1, reason: "blank JSONL records are not allowed")
            }

            let example: CorpusExample
            do {
                example = try decoder.decode(CorpusExample.self, from: Data(line.utf8))
            } catch {
                throw EvaluationDataError.invalidJSONLine(path: path, line: offset + 1, reason: error.localizedDescription)
            }
            guard example.split == expectedSplit else {
                throw EvaluationDataError.invalidRecord(id: example.id, reason: "split must be \(expectedSplit) in \(url.lastPathComponent)")
            }
            examples.append(example)
        }
        return examples
    }

    private static func loadLayouts(at url: URL) throws -> [String: LayoutProfile] {
        let file: LayoutFile = try decodeJSON(LayoutFile.self, at: url)
        guard file.layouts.count >= 2 else {
            throw EvaluationDataError.invalidLayouts("at least two distinct source profiles are required")
        }

        var profiles: [String: LayoutProfile] = [:]
        for definition in file.layouts {
            guard !definition.sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw EvaluationDataError.invalidLayouts("source IDs must not be empty")
            }
            guard profiles[definition.sourceID] == nil else {
                throw EvaluationDataError.invalidLayouts("duplicate source ID \(definition.sourceID)")
            }

            var outputs: [KeyStroke: String] = [:]
            for entry in definition.entries {
                let modifiers = try decodeModifiers(entry.modifiers, sourceID: definition.sourceID)
                let stroke = KeyStroke(keyCode: entry.keyCode, modifiers: modifiers)
                guard outputs[stroke] == nil else {
                    throw EvaluationDataError.invalidLayouts("duplicate key/modifier entry for \(definition.sourceID)")
                }
                outputs[stroke] = entry.text
            }

            do {
                profiles[definition.sourceID] = try LayoutProfile(sourceID: definition.sourceID, outputs: outputs)
            } catch {
                throw EvaluationDataError.invalidLayouts("\(definition.sourceID): \(error.localizedDescription)")
            }
        }
        return profiles
    }

    private static func loadLexicon(at url: URL) throws -> [String: [String: Int]] {
        try decodeJSON(LexiconFile.self, at: url).frequencies
    }

    private static func decodeJSON<T: Decodable>(_ type: T.Type, at url: URL) throws -> T {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EvaluationDataError.missingFile(url.path)
        }
        do {
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        } catch let error as EvaluationDataError {
            throw error
        } catch {
            throw EvaluationDataError.invalidFile(path: url.path, reason: error.localizedDescription)
        }
    }
}

private struct LayoutFile: Decodable {
    let layouts: [LayoutDefinition]
}

private struct LayoutDefinition: Decodable {
    let sourceID: String
    let entries: [LayoutEntry]
}

private struct LayoutEntry: Decodable {
    let keyCode: UInt16
    let modifiers: [String]
    let text: String
}

private struct LexiconFile: Decodable {
    let frequencies: [String: [String: Int]]
}

private func decodeModifiers(_ names: [String], sourceID: String) throws -> KeyModifiers {
    var result: KeyModifiers = []
    for name in names {
        let modifier: KeyModifiers
        switch name {
        case "shift": modifier = .shift
        case "capsLock": modifier = .capsLock
        case "option": modifier = .option
        case "command": modifier = .command
        case "control": modifier = .control
        default:
            throw EvaluationDataError.invalidLayouts("unknown modifier \(name) in \(sourceID)")
        }
        guard !result.contains(modifier) else {
            throw EvaluationDataError.invalidLayouts("duplicate modifier \(name) in \(sourceID)")
        }
        result.insert(modifier)
    }
    return result
}
