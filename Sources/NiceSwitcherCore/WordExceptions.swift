import Foundation

internal enum WordNormalization {
    private static let locale = Locale(identifier: "en_US_POSIX")

    static func key(for word: String) -> String {
        word.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive], locale: locale)
            .precomposedStringWithCanonicalMapping
    }
}

/// An explicit, local set of words that the detector must leave untouched.
public struct WordExceptions: Sendable {
    private var words: Set<String>

    public init(words: [String] = []) {
        self.words = Set(words.map(WordNormalization.key(for:)))
    }

    public func contains(_ word: String) -> Bool {
        words.contains(WordNormalization.key(for: word))
    }

    public mutating func add(_ word: String) {
        words.insert(WordNormalization.key(for: word))
    }

    public mutating func remove(_ word: String) {
        words.remove(WordNormalization.key(for: word))
    }
}
