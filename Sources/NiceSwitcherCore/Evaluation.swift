import Foundation

public struct EvaluationSummary: Codable, Equatable, Sendable {
    public let total: Int
    public let correctTokens: Int
    public let errorTokens: Int
    public let falseCorrections: Int
    public let correctedErrors: Int
    public let missedErrors: Int
    public let wrongCorrections: Int
    public let abstentions: Int
    public let categoryCounts: [String: EvaluationCategorySummary]
    public let falseCorrectionRate: Double?
    public let supportedErrorRecall: Double?

    private enum CodingKeys: String, CodingKey {
        case total
        case correctTokens
        case errorTokens
        case falseCorrections
        case correctedErrors
        case missedErrors
        case wrongCorrections
        case abstentions
        case categoryCounts
        case falseCorrectionRate
        case supportedErrorRecall
    }

    private init(counts: EvaluationCounts, categoryCounts: [String: EvaluationCategorySummary]) {
        total = counts.total
        correctTokens = counts.correctTokens
        errorTokens = counts.errorTokens
        falseCorrections = counts.falseCorrections
        correctedErrors = counts.correctedErrors
        missedErrors = counts.missedErrors
        wrongCorrections = counts.wrongCorrections
        abstentions = counts.abstentions
        self.categoryCounts = categoryCounts
        falseCorrectionRate = counts.falseCorrectionRate
        supportedErrorRecall = counts.supportedErrorRecall
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(total, forKey: .total)
        try container.encode(correctTokens, forKey: .correctTokens)
        try container.encode(errorTokens, forKey: .errorTokens)
        try container.encode(falseCorrections, forKey: .falseCorrections)
        try container.encode(correctedErrors, forKey: .correctedErrors)
        try container.encode(missedErrors, forKey: .missedErrors)
        try container.encode(wrongCorrections, forKey: .wrongCorrections)
        try container.encode(abstentions, forKey: .abstentions)
        try container.encode(categoryCounts, forKey: .categoryCounts)
        try container.encodeOptional(falseCorrectionRate, forKey: .falseCorrectionRate)
        try container.encodeOptional(supportedErrorRecall, forKey: .supportedErrorRecall)
    }

    static func summarizing(examples: [CorpusExample], predictions: [EvaluationPrediction]) throws -> EvaluationSummary {
        guard examples.count == predictions.count else { throw EvaluationDataError.predictionCountMismatch }
        guard !examples.isEmpty else { throw EvaluationDataError.emptyEvaluation }

        var total = EvaluationCounts()
        var byCategory: [String: EvaluationCounts] = [:]
        for (example, prediction) in zip(examples, predictions) {
            total.record(example: example, prediction: prediction)
            byCategory[example.category, default: EvaluationCounts()].record(example: example, prediction: prediction)
        }
        let categories = byCategory.mapValues(EvaluationCategorySummary.init(counts:))
        return EvaluationSummary(counts: total, categoryCounts: categories)
    }
}

public struct EvaluationCategorySummary: Codable, Equatable, Sendable {
    public let total: Int
    public let correctTokens: Int
    public let errorTokens: Int
    public let falseCorrections: Int
    public let correctedErrors: Int
    public let missedErrors: Int
    public let wrongCorrections: Int
    public let abstentions: Int
    public let falseCorrectionRate: Double?
    public let supportedErrorRecall: Double?

    private enum CodingKeys: String, CodingKey {
        case total
        case correctTokens
        case errorTokens
        case falseCorrections
        case correctedErrors
        case missedErrors
        case wrongCorrections
        case abstentions
        case falseCorrectionRate
        case supportedErrorRecall
    }

    fileprivate init(counts: EvaluationCounts) {
        total = counts.total
        correctTokens = counts.correctTokens
        errorTokens = counts.errorTokens
        falseCorrections = counts.falseCorrections
        correctedErrors = counts.correctedErrors
        missedErrors = counts.missedErrors
        wrongCorrections = counts.wrongCorrections
        abstentions = counts.abstentions
        falseCorrectionRate = counts.falseCorrectionRate
        supportedErrorRecall = counts.supportedErrorRecall
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(total, forKey: .total)
        try container.encode(correctTokens, forKey: .correctTokens)
        try container.encode(errorTokens, forKey: .errorTokens)
        try container.encode(falseCorrections, forKey: .falseCorrections)
        try container.encode(correctedErrors, forKey: .correctedErrors)
        try container.encode(missedErrors, forKey: .missedErrors)
        try container.encode(wrongCorrections, forKey: .wrongCorrections)
        try container.encode(abstentions, forKey: .abstentions)
        try container.encodeOptional(falseCorrectionRate, forKey: .falseCorrectionRate)
        try container.encodeOptional(supportedErrorRecall, forKey: .supportedErrorRecall)
    }
}

enum EvaluationPrediction {
    case suggestion(String)
    case abstain
}

private struct EvaluationCounts {
    var total = 0
    var correctTokens = 0
    var errorTokens = 0
    var falseCorrections = 0
    var correctedErrors = 0
    var missedErrors = 0
    var wrongCorrections = 0
    var abstentions = 0

    var falseCorrectionRate: Double? {
        correctTokens == 0 ? nil : Double(falseCorrections) / Double(correctTokens)
    }

    var supportedErrorRecall: Double? {
        errorTokens == 0 ? nil : Double(correctedErrors) / Double(errorTokens)
    }

    mutating func record(example: CorpusExample, prediction: EvaluationPrediction) {
        total += 1
        switch example.expectedText {
        case .none:
            correctTokens += 1
            if case .suggestion = prediction { falseCorrections += 1 }
        case .some(let expected):
            errorTokens += 1
            switch prediction {
            case .abstain:
                missedErrors += 1
            case .suggestion(let suggestion):
                if suggestion.utf16.elementsEqual(expected.utf16) {
                    correctedErrors += 1
                } else {
                    wrongCorrections += 1
                }
            }
        }
        if case .abstain = prediction { abstentions += 1 }
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeOptional(_ value: Double?, forKey key: Key) throws {
        if let value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}
