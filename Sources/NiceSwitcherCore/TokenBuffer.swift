public struct TokenBuffer: Sendable {
    public private(set) var context: [String] = []

    private var currentText = ""
    private var currentScalarCount = 0
    private var currentStrokes: [KeyStroke] = []
    private var currentSourceID: String?
    private var isSuppressed = false

    public init() {}

    public mutating func appendCommitted(text: String, stroke: KeyStroke, sourceID: String) {
        guard !isSuppressed else { return }

        guard !sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              CoreTextValidation.isCommittedOutput(text),
              !stroke.modifiers.hasUnknownBits else {
            suppressCurrentWord()
            return
        }

        if let currentSourceID, currentSourceID != sourceID {
            suppressCurrentWord()
            return
        }

        let outputScalarCount = text.unicodeScalars.count
        let nextScalarCount = currentScalarCount + outputScalarCount
        guard currentStrokes.count < CoreLimits.maximumTokenStrokes,
              nextScalarCount <= CoreLimits.maximumContextScalars else {
            suppressCurrentWord()
            return
        }

        let nextText = currentText + text
        guard nextText.count <= CoreLimits.maximumTokenGraphemes else {
            suppressCurrentWord()
            return
        }

        currentText = nextText
        currentScalarCount = nextScalarCount
        currentStrokes.append(stroke)
        currentSourceID = sourceID
        trimHistoryToFitCurrentWord()
    }

    public mutating func finishWord() -> TypedToken? {
        if isSuppressed {
            clearCurrentWord()
            isSuppressed = false
            return nil
        }

        guard !currentText.isEmpty,
              !currentStrokes.isEmpty,
              let currentSourceID else {
            clearCurrentWord()
            return nil
        }

        let token = TypedToken(text: currentText, sourceID: currentSourceID, strokes: currentStrokes)
        context.append(currentText)
        trimHistoryToFitCurrentWord(scalarCount: 0)
        clearCurrentWord()
        return token
    }

    public mutating func reset() {
        context.removeAll(keepingCapacity: false)
        clearCurrentWord()
        isSuppressed = false
    }

    public mutating func invalidateCurrentWord() {
        suppressCurrentWord()
    }

    private mutating func suppressCurrentWord() {
        clearCurrentWord()
        isSuppressed = true
    }

    private mutating func clearCurrentWord() {
        currentText = ""
        currentScalarCount = 0
        currentStrokes.removeAll(keepingCapacity: false)
        currentSourceID = nil
    }

    private mutating func trimHistoryToFitCurrentWord(scalarCount: Int? = nil) {
        let activeScalarCount = scalarCount ?? currentScalarCount
        while context.count > CoreLimits.maximumContextWords {
            context.removeFirst()
        }
        while contextScalarCount + activeScalarCount > CoreLimits.maximumContextScalars,
              !context.isEmpty {
            context.removeFirst()
        }
    }

    private var contextScalarCount: Int {
        context.reduce(into: 0) { count, word in
            count += word.unicodeScalars.count
        }
    }
}
