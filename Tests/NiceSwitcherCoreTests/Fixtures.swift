import Foundation
import NiceSwitcherCore

/// Small hand-authored fixtures for exercising the pipeline. These are not
/// Apple input-source identifiers or verified Apple keyboard maps.
enum FixtureLayouts {
    static let usSourceID = "fixture.us"
    static let ruSourceID = "fixture.ru"

    static let g = KeyStroke(keyCode: 10, modifiers: [])
    static let h = KeyStroke(keyCode: 11, modifiers: [])
    static let b = KeyStroke(keyCode: 12, modifiers: [])
    static let d = KeyStroke(keyCode: 13, modifiers: [])
    static let t = KeyStroke(keyCode: 14, modifiers: [])
    static let n = KeyStroke(keyCode: 15, modifiers: [])
    static let shiftedG = KeyStroke(keyCode: 10, modifiers: [.shift])

    static let wordStrokes = [g, h, b, d, t, n]

    static let us = try! LayoutProfile(
        sourceID: usSourceID,
        outputs: [
            g: "g", shiftedG: "G",
            h: "h", b: "b", d: "d", t: "t", n: "n",
            KeyStroke(keyCode: 20, modifiers: []): "é"
        ]
    )

    static let ru = try! LayoutProfile(
        sourceID: ruSourceID,
        outputs: [
            g: "п", shiftedG: "П",
            h: "р", b: "и", d: "в", t: "е", n: "т",
            KeyStroke(keyCode: 20, modifiers: []): "ё"
        ]
    )
}
