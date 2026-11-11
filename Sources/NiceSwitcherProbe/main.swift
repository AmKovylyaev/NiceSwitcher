import Foundation
import ProbeCore

#if os(macOS)
import Darwin
#else
import Glibc
#endif

enum ProbeExecutionError: Error, CustomStringConvertible {
    case unsupportedPlatform

    var description: String {
        switch self {
        case .unsupportedPlatform:
            "Accessibility probing is available only on macOS; no AX operation was attempted."
        }
    }
}

do {
    let command = try ProbeCommand.parse(Array(CommandLine.arguments.dropFirst()))
    if command.delay > 0 {
        Thread.sleep(forTimeInterval: command.delay)
    }

    #if os(macOS)
    let result = try MainActor.assumeIsolated {
        try MacOSProbe.run(command)
    }
    print(result)
    #else
    throw ProbeExecutionError.unsupportedPlatform
    #endif
} catch {
    FileHandle.standardError.write(Data("NiceSwitcherProbe: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
