import Foundation

public struct CorpusExample: Codable, Equatable, Sendable {
    public let id: String
    public let groupID: String
    public let category: String
    public let split: String
    public let text: String
    public let expectedText: String?
    public let sourceID: String
    public let targetSourceID: String
    public let surface: TokenSurface
    public let provenanceAvailable: Bool
    public let strokes: [KeyStroke]

    public init(
        id: String,
        groupID: String,
        category: String,
        split: String,
        text: String,
        expectedText: String?,
        sourceID: String,
        targetSourceID: String,
        surface: TokenSurface,
        provenanceAvailable: Bool,
        strokes: [KeyStroke]
    ) {
        self.id = id
        self.groupID = groupID
        self.category = category
        self.split = split
        self.text = text
        self.expectedText = expectedText
        self.sourceID = sourceID
        self.targetSourceID = targetSourceID
        self.surface = surface
        self.provenanceAvailable = provenanceAvailable
        self.strokes = strokes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case groupID
        case category
        case split
        case text
        case expectedText
        case sourceID
        case targetSourceID
        case surface
        case provenanceAvailable
        case strokes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        groupID = try container.decode(String.self, forKey: .groupID)
        category = try container.decode(String.self, forKey: .category)
        split = try container.decode(String.self, forKey: .split)
        text = try container.decode(String.self, forKey: .text)
        guard container.contains(.expectedText) else {
            throw DecodingError.keyNotFound(
                CodingKeys.expectedText,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "expectedText is required; use null for a preserve label")
            )
        }
        expectedText = try container.decodeIfPresent(String.self, forKey: .expectedText)
        sourceID = try container.decode(String.self, forKey: .sourceID)
        targetSourceID = try container.decode(String.self, forKey: .targetSourceID)
        surface = try container.decode(TokenSurface.self, forKey: .surface)
        provenanceAvailable = try container.decode(Bool.self, forKey: .provenanceAvailable)
        strokes = try container.decode([KeyStroke].self, forKey: .strokes)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(groupID, forKey: .groupID)
        try container.encode(category, forKey: .category)
        try container.encode(split, forKey: .split)
        try container.encode(text, forKey: .text)
        if let expectedText {
            try container.encode(expectedText, forKey: .expectedText)
        } else {
            try container.encodeNil(forKey: .expectedText)
        }
        try container.encode(sourceID, forKey: .sourceID)
        try container.encode(targetSourceID, forKey: .targetSourceID)
        try container.encode(surface, forKey: .surface)
        try container.encode(provenanceAvailable, forKey: .provenanceAvailable)
        try container.encode(strokes, forKey: .strokes)
    }
}

public enum EvaluationDataError: Error, Equatable, LocalizedError {
    case missingFile(String)
    case invalidFile(path: String, reason: String)
    case invalidJSONLine(path: String, line: Int, reason: String)
    case emptyCorpus(split: String)
    case invalidRecord(id: String, reason: String)
    case invalidLayouts(String)
    case invalidLexicon(String)
    case emptyEvaluation
    case predictionCountMismatch

    public var errorDescription: String? {
        switch self {
        case .missingFile(let path):
            return "Required evaluation data file is missing: \(path)"
        case .invalidFile(let path, let reason):
            return "Invalid evaluation data file \(path): \(reason)"
        case .invalidJSONLine(let path, let line, let reason):
            return "Invalid JSONL record at \(path):\(line): \(reason)"
        case .emptyCorpus(let split):
            return "The \(split) corpus is empty"
        case .invalidRecord(let id, let reason):
            return "Invalid corpus record \(id): \(reason)"
        case .invalidLayouts(let reason):
            return "Invalid layout fixtures: \(reason)"
        case .invalidLexicon(let reason):
            return "Invalid baseline lexicon: \(reason)"
        case .emptyEvaluation:
            return "Cannot evaluate an empty example set"
        case .predictionCountMismatch:
            return "The number of predictions must match the number of examples"
        }
    }
}

/// Loads and validates the complete, fixed corpus before any scoring occurs.
