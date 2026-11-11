import Foundation

public enum WordLexiconError: Error, Equatable {
    case emptySourceID
    case emptyWord(sourceID: String)
    case invalidFrequency(sourceID: String, word: String, frequency: Int)
}

/// A read-only lexicon keyed by the exact input-source identifier.
public struct WordLexicon: Sendable {
    private let frequencies: [String: [String: Int]]

    public init(frequencies: [String: [String: Int]]) throws {
        var normalized: [String: [String: Int]] = [:]

        for (sourceID, words) in frequencies {
            guard !sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WordLexiconError.emptySourceID
            }

            var normalizedWords: [String: Int] = [:]
            for (word, frequency) in words {
                guard !word.isEmpty else {
                    throw WordLexiconError.emptyWord(sourceID: sourceID)
                }
                guard frequency > 0 else {
                    throw WordLexiconError.invalidFrequency(sourceID: sourceID, word: word, frequency: frequency)
                }

                let key = WordNormalization.key(for: word)
                normalizedWords[key] = max(normalizedWords[key, default: 0], frequency)
            }

            normalized[sourceID] = normalizedWords
        }

        self.frequencies = normalized
    }

    public func contains(_ word: String, sourceID: String) -> Bool {
        frequencies[sourceID]?[WordNormalization.key(for: word)] != nil
    }
}

public struct CorrectionCandidate: Equatable, Sendable {
    public let original: String
    public let replacement: String
    public let targetSourceID: String

    public init(original: String, replacement: String, targetSourceID: String) {
        self.original = original
        self.replacement = replacement
        self.targetSourceID = targetSourceID
    }
}

public enum DetectionAbstentionReason: Equatable, Sendable {
    case unsupportedSurface
    case explicitException
    case protectedToken
    case originalKnown
    case conversionUnavailable
    case unchangedCandidate
    case unknownCandidate
}

public enum DetectionDecision: Equatable, Sendable {
    case suggestion(CorrectionCandidate)
    case abstain(DetectionAbstentionReason)
}

public enum Detector {
    public static func decide(
        token: TypedToken,
        source: LayoutProfile,
        target: LayoutProfile,
        surface: TokenSurface,
        exceptions: WordExceptions,
        lexicon: WordLexicon
    ) -> DetectionDecision {
        guard surface == .plainText else {
            return .abstain(.unsupportedSurface)
        }

        guard TokenProtection.isWithinRuntimeLimits(token.text) else {
            return .abstain(.protectedToken)
        }

        guard !exceptions.contains(token.text) else {
            return .abstain(.explicitException)
        }

        guard TokenProtection.canBeCheckedForMappedPunctuation(token.text, surface: surface) else {
            return .abstain(.protectedToken)
        }

        let hasPunctuation = token.text.unicodeScalars.contains { !TokenProtection.isLetter($0) }
        let allowsMappedPunctuation = hasPunctuation && sourcePunctuationMapsToTargetLetters(
            in: token,
            source: source,
            target: target
        )
        guard TokenProtection.permits(
            token.text,
            surface: surface,
            allowingMappedPunctuation: allowsMappedPunctuation
        ) else {
            return .abstain(.protectedToken)
        }

        guard !lexicon.contains(token.text, sourceID: source.sourceID),
              !lexicon.contains(token.text, sourceID: target.sourceID) else {
            return .abstain(.originalKnown)
        }

        guard let replacement = LayoutConverter.convert(token, from: source, to: target) else {
            return .abstain(.conversionUnavailable)
        }

        guard !replacement.isEmpty,
              replacement != token.text else {
            return .abstain(.unchangedCandidate)
        }

        guard TokenProtection.isAllLetters(replacement) else {
            return .abstain(.protectedToken)
        }

        guard TokenProtection.permits(replacement, surface: .plainText) else {
            return .abstain(.protectedToken)
        }

        guard lexicon.contains(replacement, sourceID: target.sourceID) else {
            return .abstain(.unknownCandidate)
        }

        return .suggestion(CorrectionCandidate(
            original: token.text,
            replacement: replacement,
            targetSourceID: target.sourceID
        ))
    }

    private static func sourcePunctuationMapsToTargetLetters(
        in token: TypedToken,
        source: LayoutProfile,
        target: LayoutProfile
    ) -> Bool {
        guard !token.strokes.isEmpty,
              token.strokes.count <= CoreLimits.maximumTokenStrokes else {
            return false
        }

        var sourceText = ""
        var foundPunctuation = false
        var sourceScalarCount = 0

        for stroke in token.strokes {
            guard let sourceOutput = source.outputs[stroke],
                  let targetOutput = target.outputs[stroke] else {
                return false
            }
            sourceScalarCount += sourceOutput.unicodeScalars.count
            guard sourceScalarCount <= CoreLimits.maximumContextScalars else {
                return false
            }
            sourceText.append(contentsOf: sourceOutput)

            if sourceOutput.unicodeScalars.allSatisfy(TokenProtection.isLetter) {
                continue
            }

            let sourceScalars = Array(sourceOutput.unicodeScalars)
            guard !sourceScalars.isEmpty,
                  sourceScalars.allSatisfy(isPunctuation),
                  targetOutput.unicodeScalars.allSatisfy(TokenProtection.isLetter) else {
                return false
            }
            foundPunctuation = true
        }

        return foundPunctuation && sourceText.utf16.elementsEqual(token.text.utf16)
    }

    private static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == "`" {
            return true
        }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation,
             .closePunctuation, .initialPunctuation, .finalPunctuation, .otherPunctuation:
            return true
        default:
            return false
        }
    }
}
