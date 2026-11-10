public struct SelectionSnapshot: Equatable, Sendable {
    public let bundleID: String?
    public let role: String?
    public let subrole: String?
    public let isEnabled: Bool?
    public let isSecureInput: Bool?
    public let selectedText: String?
    public let selectedRangeLocation: Int?
    public let selectedRangeLength: Int?
    public let selectedTextWritable: Bool?

    public init(
        bundleID: String?,
        role: String?,
        subrole: String?,
        isEnabled: Bool?,
        isSecureInput: Bool?,
        selectedText: String?,
        selectedRangeLocation: Int?,
        selectedRangeLength: Int?,
        selectedTextWritable: Bool?
    ) {
        self.bundleID = bundleID
        self.role = role
        self.subrole = subrole
        self.isEnabled = isEnabled
        self.isSecureInput = isSecureInput
        self.selectedText = selectedText
        self.selectedRangeLocation = selectedRangeLocation
        self.selectedRangeLength = selectedRangeLength
        self.selectedTextWritable = selectedTextWritable
    }
}

public enum SelectionSafetyError: Error, Equatable, CustomStringConvertible {
    case unknownOrMismatchedTarget
    case unsupportedField
    case secureField
    case disabledField
    case selectedTextMismatch
    case invalidSelectionRange
    case selectedTextNotWritable

    public var description: String {
        switch self {
        case .unknownOrMismatchedTarget: "Target information is missing or does not match."
        case .unsupportedField: "The focused element is not a supported text field."
        case .secureField: "Secure or unknown input state prevents writing."
        case .disabledField: "The focused field is disabled or its state is unknown."
        case .selectedTextMismatch: "Selected text does not exactly match the expected test word."
        case .invalidSelectionRange: "The UTF-16 selection range is missing or invalid."
        case .selectedTextNotWritable: "Selected text is not known to be writable."
        }
    }
}

public enum SelectionSafety {
    public static func validate(
        _ snapshot: SelectionSnapshot,
        expectedBundleID: String,
        expectedText: String
    ) throws {
        guard !expectedBundleID.isEmpty,
              let bundleID = snapshot.bundleID,
              bundleID == expectedBundleID else {
            throw SelectionSafetyError.unknownOrMismatchedTarget
        }

        guard let role = snapshot.role,
              let subrole = snapshot.subrole,
              ["AXTextField", "AXTextArea"].contains(role) else {
            throw SelectionSafetyError.unsupportedField
        }
        guard subrole != "AXSecureTextField",
              let isSecureInput = snapshot.isSecureInput,
              !isSecureInput else {
            throw SelectionSafetyError.secureField
        }
        guard snapshot.isEnabled == true else {
            throw SelectionSafetyError.disabledField
        }
        guard !expectedText.isEmpty,
              let selectedText = snapshot.selectedText,
              exactUTF16Equal(selectedText, expectedText) else {
            throw SelectionSafetyError.selectedTextMismatch
        }

        guard let location = snapshot.selectedRangeLocation,
              let length = snapshot.selectedRangeLength,
              location >= 0,
              length >= 0,
              !location.addingReportingOverflow(length).overflow,
              length == selectedText.utf16.count else {
            throw SelectionSafetyError.invalidSelectionRange
        }

        guard snapshot.selectedTextWritable == true else {
            throw SelectionSafetyError.selectedTextNotWritable
        }
    }

    private static func exactUTF16Equal(_ lhs: String, _ rhs: String) -> Bool {
        lhs.utf16.elementsEqual(rhs.utf16)
    }
}
