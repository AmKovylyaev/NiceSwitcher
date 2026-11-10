import XCTest
@testable import ProbeCore

final class SelectionSafetyTests: XCTestCase {
    func testAllowsSupportedTextFieldAndTextAreaRoles() throws {
        try SelectionSafety.validate(snapshot(role: "AXTextField"), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn")
        try SelectionSafety.validate(snapshot(role: "AXTextArea"), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn")
    }

    func testRequiresExactExpectedTextAndBundleID() {
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(selectedText: "hello"), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(), expectedBundleID: "com.other.Editor", expectedText: "ghbdtn"
        ))
    }

    func testRequiresExactUnicodeCodeUnits() {
        let expected = "\u{00E9}e\u{0301}"
        let selected = "e\u{0301}\u{00E9}"
        XCTAssertEqual(expected, selected, "Swift string equality treats these as canonically equivalent")

        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(selectedText: selected, rangeLength: 3),
            expectedBundleID: "com.example.Editor", expectedText: expected
        ))
    }

    func testRejectsUnsupportedOrSecureRoles() {
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(role: "AXButton"), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(subrole: "AXSecureTextField"), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
    }

    func testRejectsDisabledAndUnknownSafetyFields() {
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(isEnabled: false), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(isEnabled: nil), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(isSecureInput: true), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(isSecureInput: nil), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(role: nil), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(subrole: nil), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(bundleID: nil), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
    }

    func testRejectsNonWritableAndUnknownSelectedTextWritability() {
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(selectedTextWritable: false), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(selectedTextWritable: nil), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
    }

    func testRejectsNegativeSelectionRanges() {
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(rangeLocation: -1), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(rangeLength: -1), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
    }

    func testRejectsOverflowingSelectionRange() {
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(rangeLocation: Int.max - 5, rangeLength: 6), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
    }

    func testRejectsUnknownSelectionRangeComponents() {
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(rangeLocation: nil), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(rangeLength: nil), expectedBundleID: "com.example.Editor", expectedText: "ghbdtn"
        ))
    }

    func testUsesUTF16LengthForEmojiSelectionRanges() throws {
        let emoji = "🙂"
        try SelectionSafety.validate(
            snapshot(selectedText: emoji, rangeLength: 2),
            expectedBundleID: "com.example.Editor", expectedText: emoji
        )
        XCTAssertThrowsError(try SelectionSafety.validate(
            snapshot(selectedText: emoji, rangeLength: 1),
            expectedBundleID: "com.example.Editor", expectedText: emoji
        ))
    }

    private func snapshot(
        bundleID: String? = "com.example.Editor",
        role: String? = "AXTextField",
        subrole: String? = "AXStandardTextField",
        isEnabled: Bool? = true,
        isSecureInput: Bool? = false,
        selectedText: String? = "ghbdtn",
        rangeLocation: Int? = 2,
        rangeLength: Int? = 6,
        selectedTextWritable: Bool? = true
    ) -> SelectionSnapshot {
        SelectionSnapshot(
            bundleID: bundleID,
            role: role,
            subrole: subrole,
            isEnabled: isEnabled,
            isSecureInput: isSecureInput,
            selectedText: selectedText,
            selectedRangeLocation: rangeLocation,
            selectedRangeLength: rangeLength,
            selectedTextWritable: selectedTextWritable
        )
    }
}
