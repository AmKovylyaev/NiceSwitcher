# M0 status — 2026-11-10

The research probe and portable `ProbeCore` are implemented. GitHub Actions run [42894423303](https://github.com/AmKovylyaev/NiceSwitcher/actions/runs/42894423303) verified the reviewed probe, including its checked `unsafeDowncast` conversions: 19 tests and a release build on Swift 6.1.2, target `arm64-apple-macosx15.0`, Xcode 16.4 build 16F6, with no compiler warnings. The later core/detector run [42899945526](https://github.com/AmKovylyaev/NiceSwitcher/actions/runs/42899945526) also passed macOS Intel host tests/release build and an explicit arm64 release cross-build. A cross-build does not establish native M1 runtime or performance.

The only successful write result is `write_accepted_unverified`. No live editor Undo/Redo scenario has been run, so every cell in the compatibility matrix is `not_run`. R8 and editor compatibility remain unproven. The probe is not a background switcher and does not claim production support.

The Linux CLI rejects AX commands as unsupported before any Accessibility operation. No live application, permission prompt, text write, Undo, Redo, or machine feedback was observed in the implementation environment.
