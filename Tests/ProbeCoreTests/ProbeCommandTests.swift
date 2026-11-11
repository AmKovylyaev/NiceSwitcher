import XCTest
@testable import ProbeCore

final class ProbeCommandTests: XCTestCase {
    func testParsesInspectCommand() throws {
        let command = try ProbeCommand.parse([
            "inspect", "--bundle-id", "com.example.Editor", "--delay", "5"
        ])

        XCTAssertEqual(command.operation, .inspect)
        XCTAssertEqual(command.bundleID, "com.example.Editor")
        XCTAssertNil(command.expectedText)
        XCTAssertNil(command.replacementText)
        XCTAssertEqual(command.delay, 5)
    }

    func testParsesReplaceSelectedCommand() throws {
        let command = try ProbeCommand.parse([
            "replace-selected", "--bundle-id", "com.example.Editor",
            "--expected", "ghbdtn", "--replacement", "привет", "--delay", "0"
        ])

        XCTAssertEqual(command.operation, .replaceSelected)
        XCTAssertEqual(command.expectedText, "ghbdtn")
        XCTAssertEqual(command.replacementText, "привет")
        XCTAssertEqual(command.delay, 0)
    }

    func testRejectsMissingArguments() {
        XCTAssertThrowsError(try ProbeCommand.parse([]))
        XCTAssertThrowsError(try ProbeCommand.parse(["inspect", "--bundle-id"]))
        XCTAssertThrowsError(try ProbeCommand.parse(["replace-selected", "--bundle-id", "app"]))
    }

    func testRejectsDuplicateFlags() {
        XCTAssertThrowsError(try ProbeCommand.parse([
            "inspect", "--bundle-id", "one", "--bundle-id", "two", "--delay", "1"
        ]))
        XCTAssertThrowsError(try ProbeCommand.parse([
            "replace-selected", "--bundle-id", "app", "--expected", "a",
            "--expected", "b", "--replacement", "x", "--delay", "1"
        ]))
    }

    func testRejectsUnknownFlagsAndCommands() {
        XCTAssertThrowsError(try ProbeCommand.parse([
            "inspect", "--bundle-id", "app", "--delay", "1", "--verbose"
        ]))
        XCTAssertThrowsError(try ProbeCommand.parse(["undo", "--bundle-id", "app"]))
    }

    func testAcceptsDelayBoundsAndRejectsInvalidValues() throws {
        for value in ["0", "30"] {
            let command = try ProbeCommand.parse([
                "inspect", "--bundle-id", "app", "--delay", value
            ])
            XCTAssertEqual(command.delay, Double(value))
        }

        for value in ["NaN", "Infinity", "-Infinity", "-0.1", "30.1", "1e309", ""] {
            XCTAssertThrowsError(try ProbeCommand.parse([
                "inspect", "--bundle-id", "app", "--delay", value
            ]), "Should reject delay \(value)")
        }
    }

    func testRejectsEmptyBundleIDAndWords() {
        XCTAssertThrowsError(try ProbeCommand.parse([
            "inspect", "--bundle-id", "", "--delay", "1"
        ]))
        XCTAssertThrowsError(try ProbeCommand.parse([
            "replace-selected", "--bundle-id", "app", "--expected", "",
            "--replacement", "x", "--delay", "1"
        ]))
        XCTAssertThrowsError(try ProbeCommand.parse([
            "replace-selected", "--bundle-id", "app", "--expected", "x",
            "--replacement", "", "--delay", "1"
        ]))
    }

    func testRejectsWordsLongerThan64GraphemeClusters() {
        let tooLong = String(repeating: "a", count: 65)
        XCTAssertThrowsError(try replaceCommand(expected: tooLong, replacement: "x"))
        XCTAssertThrowsError(try replaceCommand(expected: "x", replacement: tooLong))

        let familyEmoji64 = String(repeating: "👨‍👩‍👧‍👦", count: 64)
        XCTAssertNoThrow(try replaceCommand(expected: familyEmoji64, replacement: "x"))
    }

    func testRejectsLineBreaksInWords() {
        XCTAssertThrowsError(try replaceCommand(expected: "first\nsecond", replacement: "x"))
        XCTAssertThrowsError(try replaceCommand(expected: "x", replacement: "first\rsecond"))
    }

    private func replaceCommand(expected: String, replacement: String) throws -> ProbeCommand {
        try ProbeCommand.parse([
            "replace-selected", "--bundle-id", "app", "--expected", expected,
            "--replacement", replacement, "--delay", "1"
        ])
    }
}
