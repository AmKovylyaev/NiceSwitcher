import Foundation

public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let shift = Self(rawValue: 1 << 0)
    public static let capsLock = Self(rawValue: 1 << 1)
    public static let option = Self(rawValue: 1 << 2)
    public static let command = Self(rawValue: 1 << 3)
    public static let control = Self(rawValue: 1 << 4)

    fileprivate static let supportedMask: UInt8 =
        shift.rawValue | capsLock.rawValue | option.rawValue | command.rawValue | control.rawValue

    internal var hasUnknownBits: Bool {
        rawValue & ~Self.supportedMask != 0
    }
}

public struct KeyStroke: Hashable, Codable, Sendable {
    public let keyCode: UInt16
    public let modifiers: KeyModifiers

    public init(keyCode: UInt16, modifiers: KeyModifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let names = try container.decode([String].self, forKey: .modifiers)
        var decodedModifiers: KeyModifiers = []
        for name in names {
            let modifier: KeyModifiers
            switch name {
            case "shift": modifier = .shift
            case "capsLock": modifier = .capsLock
            case "option": modifier = .option
            case "command": modifier = .command
            case "control": modifier = .control
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .modifiers,
                    in: container,
                    debugDescription: "Unknown modifier: \(name)"
                )
            }
            guard !decodedModifiers.contains(modifier) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .modifiers,
                    in: container,
                    debugDescription: "Duplicate modifier: \(name)"
                )
            }
            decodedModifiers.insert(modifier)
        }
        modifiers = decodedModifiers
    }

    public func encode(to encoder: Encoder) throws {
        guard !modifiers.hasUnknownBits else {
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode unknown key modifier bits")
            )
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        var names: [String] = []
        if modifiers.contains(.shift) { names.append("shift") }
        if modifiers.contains(.capsLock) { names.append("capsLock") }
        if modifiers.contains(.option) { names.append("option") }
        if modifiers.contains(.command) { names.append("command") }
        if modifiers.contains(.control) { names.append("control") }
        try container.encode(names, forKey: .modifiers)
    }
}

public enum LayoutProfileError: Error, Equatable {
    case emptySourceID
    case invalidOutput(KeyStroke)
    case unknownModifierBits(KeyStroke)
}

public struct LayoutProfile: Sendable {
    public let sourceID: String
    public let outputs: [KeyStroke: String]

    public init(sourceID: String, outputs: [KeyStroke: String]) throws {
        guard !sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LayoutProfileError.emptySourceID
        }

        for (stroke, output) in outputs {
            guard !stroke.modifiers.hasUnknownBits else {
                throw LayoutProfileError.unknownModifierBits(stroke)
            }
            guard CoreTextValidation.isCommittedOutput(output) else {
                throw LayoutProfileError.invalidOutput(stroke)
            }
        }

        self.sourceID = sourceID
        self.outputs = outputs
    }
}

internal enum CoreLimits {
    static let maximumTokenGraphemes = 64
    static let maximumTokenStrokes = 64
    static let maximumContextWords = 4
    static let maximumContextScalars = 256
}

internal enum CoreTextValidation {
    static func isCommittedOutput(_ text: String) -> Bool {
        guard !text.isEmpty,
              text.unicodeScalars.count <= CoreLimits.maximumContextScalars,
              text.count == 1 else {
            return false
        }

        return text.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
                && scalar.properties.generalCategory != .control
        }
    }
}

public enum LayoutConverter {
    public static func convert(_ token: TypedToken, from source: LayoutProfile, to target: LayoutProfile) -> String? {
        guard !token.sourceID.isEmpty,
              token.sourceID == source.sourceID,
              source.sourceID != target.sourceID,
              !token.text.isEmpty,
              token.text.count <= CoreLimits.maximumTokenGraphemes,
              token.text.unicodeScalars.count <= CoreLimits.maximumContextScalars,
              !token.strokes.isEmpty,
              token.strokes.count <= CoreLimits.maximumTokenStrokes else {
            return nil
        }

        var sourceUTF16: [UInt16] = []
        var sourceScalarCount = 0
        var targetText = ""
        var targetScalarCount = 0

        for stroke in token.strokes {
            guard !stroke.modifiers.hasUnknownBits,
                  !stroke.modifiers.contains(.command),
                  !stroke.modifiers.contains(.control),
                  let sourceOutput = source.outputs[stroke],
                  CoreTextValidation.isCommittedOutput(sourceOutput),
                  let targetOutput = target.outputs[stroke],
                  CoreTextValidation.isCommittedOutput(targetOutput) else {
                return nil
            }

            sourceScalarCount += sourceOutput.unicodeScalars.count
            targetScalarCount += targetOutput.unicodeScalars.count
            guard sourceScalarCount <= CoreLimits.maximumContextScalars,
                  targetScalarCount <= CoreLimits.maximumContextScalars else {
                return nil
            }

            sourceUTF16.append(contentsOf: sourceOutput.utf16)
            targetText.append(contentsOf: targetOutput)
        }

        guard sourceUTF16.elementsEqual(token.text.utf16),
              targetText.count <= CoreLimits.maximumTokenGraphemes else {
            return nil
        }

        return targetText
    }
}
