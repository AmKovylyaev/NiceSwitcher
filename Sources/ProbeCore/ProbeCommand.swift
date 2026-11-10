import Foundation

public struct ProbeCommand: Equatable, Sendable {
    public enum Operation: String, Equatable, Sendable {
        case inspect
        case replaceSelected = "replace-selected"
    }

    public let operation: Operation
    public let bundleID: String
    public let expectedText: String?
    public let replacementText: String?
    public let delay: TimeInterval

    private init(
        operation: Operation,
        bundleID: String,
        expectedText: String?,
        replacementText: String?,
        delay: TimeInterval
    ) {
        self.operation = operation
        self.bundleID = bundleID
        self.expectedText = expectedText
        self.replacementText = replacementText
        self.delay = delay
    }

    public static func parse(_ arguments: [String]) throws -> ProbeCommand {
        guard let rawOperation = arguments.first,
              let operation = Operation(rawValue: rawOperation) else {
            throw ProbeCommandError.invalidArguments
        }

        let requiredFlags: Set<String>
        switch operation {
        case .inspect:
            requiredFlags = ["--bundle-id", "--delay"]
        case .replaceSelected:
            requiredFlags = ["--bundle-id", "--expected", "--replacement", "--delay"]
        }

        var values: [String: String] = [:]
        var index = 1
        while index < arguments.count {
            let flag = arguments[index]
            guard requiredFlags.contains(flag), values[flag] == nil,
                  index + 1 < arguments.count else {
                throw ProbeCommandError.invalidArguments
            }

            let value = arguments[index + 1]
            guard !value.isEmpty else {
                throw ProbeCommandError.invalidArguments
            }
            values[flag] = value
            index += 2
        }

        guard values.count == requiredFlags.count,
              let bundleID = values["--bundle-id"],
              !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let rawDelay = values["--delay"],
              let delay = Double(rawDelay), delay.isFinite, (0...30).contains(delay) else {
            throw ProbeCommandError.invalidArguments
        }

        let expectedText = values["--expected"]
        let replacementText = values["--replacement"]
        if operation == .replaceSelected {
            guard let expectedText, isValidWord(expectedText),
                  let replacementText, isValidWord(replacementText) else {
                throw ProbeCommandError.invalidArguments
            }
        }

        return ProbeCommand(
            operation: operation,
            bundleID: bundleID,
            expectedText: expectedText,
            replacementText: replacementText,
            delay: delay
        )
    }

    private static func isValidWord(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 64 &&
            !value.unicodeScalars.contains(where: CharacterSet.newlines.contains)
    }
}

public enum ProbeCommandError: Error, Equatable, CustomStringConvertible {
    case invalidArguments

    public var description: String {
        "Invalid arguments. Use inspect or replace-selected with the required options."
    }
}
