public struct TypedToken: Hashable, Sendable {
    public let text: String
    public let sourceID: String
    public let strokes: [KeyStroke]

    public init(text: String, sourceID: String, strokes: [KeyStroke]) {
        self.text = text
        self.sourceID = sourceID
        self.strokes = strokes
    }
}
