# NiceSwitcher

NiceSwitcher is a local Russian/English layout-switcher project for macOS. The repository currently contains the requirements and a small research probe for testing one explicitly selected synthetic word; it is not a background switcher.

The probe's portable parser and safety checks run on Linux and macOS. Its Accessibility adapter is macOS-only, performs one explicitly requested selected-text write, and reports `write_accepted_unverified`; this does not establish Undo/Redo support or R8.

## Build and test

Requires Swift 6.0 or later. The probe targets macOS 13 or later; product support has not been established.

```sh
swift --version
swift test
swift build -c release
```

On macOS, follow the [M0 live-test runbook](docs/validation/m0-runbook.md) before attempting AX access. For example, while a Notes window containing only the synthetic word `ghbdtn` is frontmost and that word alone is selected:

```sh
.build/release/NiceSwitcherProbe replace-selected --bundle-id com.apple.Notes --expected ghbdtn --replacement привет --delay 5
```

## Documentation

- [Project requirements](docs/mac-layout-switcher-requirements.md)
- [M0 live-test runbook](docs/validation/m0-runbook.md)
- [Compatibility matrix](docs/validation/compatibility-matrix.md)
- [Current M0 status](docs/validation/m0-status.md)

The first milestone checks whether a candidate text change can become a separate operation in each editor's standard Undo/Redo history. An accepted Accessibility write is not evidence that this requirement is met.
