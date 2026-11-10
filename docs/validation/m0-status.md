# M0 status — 2026-11-10

The research probe and portable `ProbeCore` are implemented. Parser and selection-safety unit tests pass on Swift 6.1.2 running on Linux. GitHub Actions run [42893711059](https://github.com/AmKovylyaev/NiceSwitcher/actions/runs/42893711059) passed for commit `f6d1767`: 19 tests and a release build on Swift 6.1.2, target `arm64-apple-macosx15.0`, Xcode 16.4 build 16F6. That compile reported two warnings recommending `unsafeDowncast` for the checked AXUIElement and AXValue conversions; the follow-up commit applies that compiler guidance, and has not yet had a separate macOS CI run.

The only successful write result is `write_accepted_unverified`. No live editor Undo/Redo scenario has been run, so every cell in the compatibility matrix is `not_run`. R8 and editor compatibility remain unproven. The probe is not a background switcher and does not claim production support.

The Linux CLI rejects AX commands as unsupported before any Accessibility operation. No live application, permission prompt, text write, Undo, Redo, or machine feedback was observed in the implementation environment.
