#if os(macOS)
import AppKit
import ApplicationServices
import Carbon
import Foundation
import ProbeCore

private struct AXCapture {
    let focusedElement: AXUIElement
    let snapshot: SelectionSnapshot
}

@MainActor
enum MacOSProbe {
    static func run(_ command: ProbeCommand) throws -> String {
        guard AXIsProcessTrusted() else {
            throw AXProbeError.accessibilityPermissionRequired
        }
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier == command.bundleID else {
            throw AXProbeError.targetIsNotFrontmost
        }
        guard let initialCapture = capture(
            application: application,
            includeSelection: command.operation == .replaceSelected
        ), initialCapture.snapshot.bundleID == command.bundleID else {
            throw AXProbeError.cannotReadFocusedElement
        }

        switch command.operation {
        case .inspect:
            return inspectionLine(initialCapture.snapshot)
        case .replaceSelected:
            guard let expectedText = command.expectedText,
                  let replacementText = command.replacementText else {
                throw AXProbeError.invalidCommand
            }
            try SelectionSafety.validate(
                initialCapture.snapshot,
                expectedBundleID: command.bundleID,
                expectedText: expectedText
            )

            guard !IsSecureEventInputEnabled() else {
                throw AXProbeError.secureInputActive
            }
            guard let refreshedApplication = NSWorkspace.shared.frontmostApplication,
                  refreshedApplication.bundleIdentifier == command.bundleID,
                  let refreshed = capture(application: refreshedApplication, includeSelection: true),
                  CFEqual(initialCapture.focusedElement, refreshed.focusedElement),
                  refreshed.snapshot == initialCapture.snapshot,
                  NSWorkspace.shared.frontmostApplication?.bundleIdentifier == command.bundleID,
                  !IsSecureEventInputEnabled() else {
                throw AXProbeError.selectionChanged
            }
            try SelectionSafety.validate(
                refreshed.snapshot,
                expectedBundleID: command.bundleID,
                expectedText: expectedText
            )

            let result = AXUIElementSetAttributeValue(
                initialCapture.focusedElement,
                kAXSelectedTextAttribute as CFString,
                replacementText as CFString
            )
            guard result == .success else {
                throw AXProbeError.writeNotConfirmed
            }
            return "status=write_accepted_unverified"
        }
    }

    private static func capture(application: NSRunningApplication, includeSelection: Bool) -> AXCapture? {
        guard let bundleID = application.bundleIdentifier else { return nil }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue,
        CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return nil
        }
        let focusedElement = unsafeDowncast(focusedValue, to: AXUIElement.self)

        let role = stringAttribute(kAXRoleAttribute, on: focusedElement)
        let subrole = stringAttribute(kAXSubroleAttribute, on: focusedElement)
        let enabled = boolAttribute(kAXEnabledAttribute, on: focusedElement)
        var secureInput = IsSecureEventInputEnabled()
        var selectedText: String?
        var selectionRange: CFRange?
        var writable: Bool?

        // Do not read selected text or selection attributes until the focused
        // element is known to be a non-secure, enabled text field.
        if includeSelection,
           isEligibleForSelectionRead(role: role, subrole: subrole, enabled: enabled, secureInput: secureInput),
           !IsSecureEventInputEnabled() {
            selectedText = stringAttribute(kAXSelectedTextAttribute, on: focusedElement)
            selectionRange = rangeAttribute(kAXSelectedTextRangeAttribute, on: focusedElement)
            var settable = DarwinBoolean(false)
            let writabilityResult = AXUIElementIsAttributeSettable(
                focusedElement,
                kAXSelectedTextAttribute as CFString,
                &settable
            )
            writable = writabilityResult == .success ? settable.boolValue : nil
            secureInput = IsSecureEventInputEnabled()
            if secureInput {
                selectedText = nil
                selectionRange = nil
                writable = nil
            }
        }

        let snapshot = SelectionSnapshot(
            bundleID: bundleID,
            role: role,
            subrole: subrole,
            isEnabled: enabled,
            isSecureInput: secureInput,
            selectedText: selectedText,
            selectedRangeLocation: selectionRange?.location,
            selectedRangeLength: selectionRange?.length,
            selectedTextWritable: writable
        )
        return AXCapture(focusedElement: focusedElement, snapshot: snapshot)
    }

    private static func isEligibleForSelectionRead(
        role: String?,
        subrole: String?,
        enabled: Bool?,
        secureInput: Bool
    ) -> Bool {
        guard let role, ["AXTextField", "AXTextArea"].contains(role),
              let subrole, subrole != "AXSecureTextField",
              enabled == true else {
            return false
        }
        return !secureInput
    }

    private static func stringAttribute(_ name: String, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func boolAttribute(_ name: String, on element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? Bool
    }

    private static func rangeAttribute(_ name: String, on element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return range
    }

    private static func inspectionLine(_ snapshot: SelectionSnapshot) -> String {
        return "status=inspected role=\(snapshot.role ?? "unknown") " +
            "subrole=\(snapshot.subrole ?? "unknown") " +
            "enabled=\(snapshot.isEnabled.map(String.init) ?? "unknown") " +
            "secure_input=\(snapshot.isSecureInput.map(String.init) ?? "unknown") " +
            "selection=not_read"
    }
}

private enum AXProbeError: Error, CustomStringConvertible {
    case accessibilityPermissionRequired
    case targetIsNotFrontmost
    case cannotReadFocusedElement
    case secureInputActive
    case selectionChanged
    case writeNotConfirmed
    case invalidCommand

    var description: String {
        switch self {
        case .accessibilityPermissionRequired:
            "Accessibility permission is required. Enable it manually in System Settings."
        case .targetIsNotFrontmost:
            "The explicitly selected bundle ID is not the frontmost application."
        case .cannotReadFocusedElement:
            "The focused Accessibility element or required attributes are unavailable."
        case .secureInputActive:
            "Secure input is active; no text was written."
        case .selectionChanged:
            "The focused element or selection changed; no text was written."
        case .writeNotConfirmed:
            "The Accessibility write did not report success; the text state may be unknown. Check the field before any new attempt."
        case .invalidCommand:
            "The command is missing required test values."
        }
    }
}
#endif
