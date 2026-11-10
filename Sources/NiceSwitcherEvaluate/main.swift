import Foundation
import NiceSwitcherCore
#if os(Linux)
import Glibc
#else
import Darwin
#endif

@main
struct NiceSwitcherEvaluate {
    static func main() {
        do {
            let dataDirectory = try parseDataDirectory(Array(CommandLine.arguments.dropFirst()))
            let dataset = try EvaluationDataset.load(dataDirectory: dataDirectory)
            let output = EvaluationOutput(
                tuningRows: dataset.tuningExamples.count,
                tuningGroups: Set(dataset.tuningExamples.map(\.groupID)).count,
                heldOutRows: dataset.heldOutExamples.count,
                heldOutGroups: Set(dataset.heldOutExamples.map(\.groupID)).count,
                tuning: try dataset.tuningSummary(),
                heldOut: try dataset.heldOutSummary()
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            FileHandle.standardOutput.write(try encoder.encode(output))
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("NiceSwitcherEvaluate: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func parseDataDirectory(_ arguments: [String]) throws -> URL {
        if arguments == ["--help"] {
            print("Usage: swift run NiceSwitcherEvaluate --data-dir <path>")
            exit(EXIT_SUCCESS)
        }
        guard arguments.count == 2, arguments[0] == "--data-dir", !arguments[1].isEmpty else {
            throw CommandLineError.usage
        }
        let path = arguments[1]
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(path, isDirectory: true)
    }
}

private struct EvaluationOutput: Encodable {
    let tuningRows: Int
    let tuningGroups: Int
    let heldOutRows: Int
    let heldOutGroups: Int
    let tuning: EvaluationSummary
    let heldOut: EvaluationSummary
}

private enum CommandLineError: Error, LocalizedError {
    case usage

    var errorDescription: String? {
        "Usage: swift run NiceSwitcherEvaluate --data-dir <path>"
    }
}
