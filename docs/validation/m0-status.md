# M0 status — 2026-11-10

The research probe and portable `ProbeCore` are implemented. Parser and selection-safety unit tests pass on Swift 6.1.2 running on Linux. The macOS Accessibility adapter is conditionally compiled and has not been built or run against an Apple SDK in this environment.

The only successful write result is `write_accepted_unverified`. No Undo/Redo scenario has been run on a Mac, so every cell in the compatibility matrix is `not_run`. R8 and editor compatibility remain unproven. The probe is not a background switcher and does not claim production support.

The Linux CLI rejects AX commands as unsupported before any Accessibility operation. No live application, permission prompt, text write, Undo, Redo, or machine feedback was observed here.
