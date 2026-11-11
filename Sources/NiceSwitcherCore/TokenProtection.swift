import Foundation

public enum TokenSurface: String, Codable, Equatable, Sendable {
    case plainText
    case code
    case address
    case secure
    case unknown
}

/// Applies conservative lexical and surface checks before a token can be
/// considered for a layout correction.
public enum TokenProtection {
    public static func permits(_ token: String, surface: TokenSurface) -> Bool {
        permits(token, surface: surface, allowingMappedPunctuation: false)
    }

    internal static func permits(
        _ token: String,
        surface: TokenSurface,
        allowingMappedPunctuation: Bool
    ) -> Bool {
        guard canBeCheckedForMappedPunctuation(token, surface: surface) else {
            return false
        }

        let scalars = Array(token.unicodeScalars)
        let nonLetters = scalars.filter { !isLetter($0) }
        guard nonLetters.allSatisfy({
            isPermittedMappedPunctuation($0, allowingMappedPunctuation: allowingMappedPunctuation)
        }) else {
            return false
        }

        return true
    }

    internal static func canBeCheckedForMappedPunctuation(
        _ token: String,
        surface: TokenSurface
    ) -> Bool {
        guard surface == .plainText,
              isWithinRuntimeLimits(token),
              token.count >= 3 else {
            return false
        }

        let scalars = Array(token.unicodeScalars)
        guard !scalars.isEmpty,
              !isAddressOrPathLike(token),
              !scalars.contains(where: isUnsafeScalar) else {
            return false
        }

        let letters = scalars.filter(isLetter)
        guard !letters.isEmpty,
              !isMixedOrUnsupportedScript(letters),
              !isAllCaps(letters),
              !isCamelCaseIdentifier(letters) else {
            return false
        }

        let nonLetters = scalars.filter { !isLetter($0) }
        return nonLetters.allSatisfy(isMappablePunctuation)
    }

    internal static func isWithinRuntimeLimits(_ token: String) -> Bool {
        token.unicodeScalars.prefix(CoreLimits.maximumContextScalars + 1).count <= CoreLimits.maximumContextScalars
            && token.prefix(CoreLimits.maximumTokenGraphemes + 1).count <= CoreLimits.maximumTokenGraphemes
    }

    internal static func isAllLetters(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy(isLetter)
    }

    internal static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
            return true
        default:
            return false
        }
    }

    private static func isAddressOrPathLike(_ token: String) -> Bool {
        let lowered = token.lowercased()
        return lowered.contains("://")
            || lowered.hasPrefix("www.")
            || isDomainLike(token)
            || token.contains("@")
            || token.contains("/")
            || token.contains("\\")
            || token.contains("~")
            || token.contains("_")
    }

    private static func isDomainLike(_ token: String) -> Bool {
        let labels = token.split(separator: ".")
        guard labels.count >= 2,
              labels.allSatisfy({ label in
                  guard let first = label.first, let last = label.last,
                        first != "-", last != "-" else {
                      return false
                  }
                  return label.unicodeScalars.allSatisfy { scalar in
                      isLetter(scalar)
                          || scalar.properties.generalCategory == .decimalNumber
                          || scalar == "-"
                  }
              }),
              let topLevelDomain = labels.last,
              topLevelDomain.count >= 2 else {
            return false
        }

        return topLevelDomain.unicodeScalars.allSatisfy(isLetter)
    }

    private static func isUnsafeScalar(_ scalar: Unicode.Scalar) -> Bool {
        if CharacterSet.whitespacesAndNewlines.contains(scalar) {
            return true
        }

        switch scalar.properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator, .surrogate,
             .privateUse, .unassigned, .decimalNumber, .letterNumber, .otherNumber,
             .mathSymbol, .currencySymbol, .otherSymbol:
            return true
        default:
            break
        }

        let value = scalar.value
        return (0x1F000...0x1FAFF).contains(value)
            || (0x2600...0x27BF).contains(value)
            || value == 0xFE0F
            || value == 0x20E3
    }

    private static func isMixedOrUnsupportedScript(_ letters: [Unicode.Scalar]) -> Bool {
        var sawLatin = false
        var sawCyrillic = false

        for scalar in letters {
            let value = scalar.value
            if isLatin(value) {
                sawLatin = true
            } else if isCyrillic(value) {
                sawCyrillic = true
            } else {
                return true
            }
        }

        return sawLatin && sawCyrillic
    }

    private static func isLatin(_ value: UInt32) -> Bool {
        (0x0041...0x024F).contains(value)
            || (0x1E00...0x1EFF).contains(value)
            || (0xAB30...0xAB6F).contains(value)
    }

    private static func isCyrillic(_ value: UInt32) -> Bool {
        (0x0400...0x052F).contains(value)
            || (0x1C80...0x1C8F).contains(value)
            || (0x2DE0...0x2DFF).contains(value)
            || (0xA640...0xA69F).contains(value)
    }

    private static func isAllCaps(_ letters: [Unicode.Scalar]) -> Bool {
        letters.count >= 2 && letters.allSatisfy { scalar in
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .titlecaseLetter:
                return true
            default:
                return false
            }
        }
    }

    private static func isCamelCaseIdentifier(_ letters: [Unicode.Scalar]) -> Bool {
        guard letters.count >= 3 else { return false }

        let categories = letters.map { $0.properties.generalCategory }
        for index in 1..<categories.count {
            if categories[index] == .uppercaseLetter || categories[index] == .titlecaseLetter {
                if categories[..<index].contains(.lowercaseLetter) {
                    return true
                }
            }
        }

        let uppercasePrefixLength = categories.prefix { category in
            category == .uppercaseLetter || category == .titlecaseLetter
        }.count
        return uppercasePrefixLength >= 2 && uppercasePrefixLength < categories.count
    }

    private static func isPermittedMappedPunctuation(
        _ scalar: Unicode.Scalar,
        allowingMappedPunctuation: Bool
    ) -> Bool {
        allowingMappedPunctuation && isMappablePunctuation(scalar)
    }

    private static func isMappablePunctuation(_ scalar: Unicode.Scalar) -> Bool {
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
