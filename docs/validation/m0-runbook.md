# M0 macOS live-test runbook

This runbook covers a manual research probe for one selected synthetic word. It does not install an input method, background service, or system permission, and it does not automate selection or observe subsequent typing.

## Prepare the Mac

Use a Mac running macOS 13 or later and Swift 6.0 or later. macOS 13 is only the probe's deployment floor; it does not guarantee that installed Command Line Tools include Swift 6. Install or update Xcode Command Line Tools yourself if needed:

```sh
xcode-select --install
```

From the repository root, record the toolchain and run the portable checks:

```sh
swift --version
swift test
swift build
swift build -c release
```

The probe requires Accessibility access. If the CLI reports that access is unavailable, add the executable that you are running to **System Settings → Privacy & Security → Accessibility** yourself, then retry. The probe never changes this permission. On Linux, the CLI exits with an unsupported-platform error and performs no AX operation.

## Inspect one field

Open a plain, unsaved note or another disposable editor field. Type only the synthetic text `ghbdtn`, select exactly those six letters, and leave the target application frontmost. Do not use a password field, a saved document, a form, or a message you might send.

From Terminal, run the command below, then switch back to the target application within five seconds so it is frontmost when the probe checks it:

```sh
.build/release/NiceSwitcherProbe inspect --bundle-id com.apple.Notes --delay 5
```

Replace `com.apple.Notes` with the exact bundle ID of the test application. `inspect` prints only role, subrole, enabled/secure state, and the fact that selection content was not read. It does not read selected text or change the field.

## Attempt one synthetic replacement

Return to the disposable field, select only `ghbdtn` again, then run:

```sh
.build/release/NiceSwitcherProbe replace-selected --bundle-id com.apple.Notes --expected ghbdtn --replacement привет --delay 5
```

Switch back to the target app within the delay. A zero exit code prints `status=write_accepted_unverified`: the Accessibility API accepted one write to `AXSelectedText`. The command never prints selected text. An unknown or unsafe field, permission failure, app/focus change, or mismatched selection exits nonzero before the write. If the AX write itself does not report success, the text state may be unknown; check the field manually before considering another attempt. The CLI never retries. A local recheck and the write are not an atomic transaction.

The probe does not select text, send keystrokes, use the clipboard, read the whole document, or observe what happens after it exits. It queries selected text only for the explicit replacement attempt, after confirming a known enabled text field, a non-secure subrole, and inactive secure input. It then requires exact UTF-16 content, a valid UTF-16 range, the requested bundle ID, and writable `AXSelectedText`.

Switching between Terminal and the target, selecting text, or moving focus may change how an editor groups native Undo operations. A manually selected-word replacement is exploratory evidence only; it does not prove that an automatic in-place correction would group the same way. To reduce this disturbance, start the CLI first with a 15-second delay, then type and select only `ghbdtn` in the target app and keep focus there until it runs:

```sh
.build/release/NiceSwitcherProbe replace-selected --bundle-id com.apple.Notes --expected ghbdtn --replacement привет --delay 15
```

Compare Undo grouping with ordinary typing in that same editor and field. Record this procedure separately from the five-second launch-and-switch trial. Choosing the eventual production correction mechanism remains open until the M0 evidence is reviewed.

## Check Undo and Redo manually

Record the application, field type, macOS build, SDK, app version, and that the mechanism was `AXSelectedText`. Keep evidence limited to synthetic text and observations; save any report under ignored `artifacts/`.

After each accepted write, observe the edited field and exercise the editor's own controls. At minimum, test:

1. ⌘Z restores exactly `ghbdtn`; a second ⌘Z undoes the preceding editor action rather than changing unrelated text.
2. ⇧⌘Z restores the preceding action and then the replacement, with no duplicate replacement.
3. Continue typing after the replacement, then undo the new typing and the replacement separately.
4. Repeat Undo/Redo from the editor menus, after waiting more than 30 seconds, after switching windows, and after the CLI process has exited.
5. Repeat in each target field from the compatibility matrix, including formatted text and a selection next to an emoji where applicable.
6. For U7, undo the candidate replacement, make a new independent edit, then verify the editor's normal branch behavior clears or updates Redo as expected. Record the exact sequence and result.
7. For U8, make two candidate replacements, C1 and C2, in separate synthetic words with an ordinary edit B between them. Undo in the order C2, B, C1; Redo in the order C1, B, C2. Verify each action is separate, ordered correctly, and not repeated.

The probe cannot report whether Undo or Redo was observed, cannot correlate a later edit with its change, and cannot establish that the write became one editor history operation. Only a human's recorded observation can fill those matrix cells in this milestone. Never enter or send real form, email, or chat content during these checks.

## Record results

For each app and field, fill a separate copy of this template. Use only `not_run`, `pass`, `fail`, or `blocked` for each status. `pass` requires the actual manual steps and recorded evidence for that specific app and field; an exit code of zero or a visually correct replacement is not sufficient. Distinguish the human observation of C (the candidate replacement) versus B (a later ordinary edit) from machine feedback availability. A successful AX call remains `write_accepted_unverified`, never `undo_passed`.

```text
Surface:
macOS build:
SDK:
App version:
Field type:
Mechanism:
Evidence location (synthetic-only):

U1: not_run — evidence:
U2: not_run — evidence:
U3: not_run — evidence:
U4: not_run — evidence:
U5: not_run — evidence:
U6: not_run — evidence:
U7: not_run — evidence:
U8: not_run — evidence:
U9: not_run — evidence:
U10: not_run — evidence:
S1: not_run — evidence:
S3: not_run — evidence:
S5: not_run — evidence:
Human observation of C vs B: not_run — evidence:
Machine feedback for C/B: not_run — available/unavailable/unknown and evidence:
Redo: not_run — evidence:
Undo/Redo menu: not_run — evidence:
Manual correction: not_run — evidence:

Aggregate U1–U10 status: not_run
```

Only set the aggregate U1–U10 matrix cell to `pass` when all ten individual U cases above are `pass` with evidence for the same app, version, and field. Any `fail`, `blocked`, or `not_run` case prevents an aggregate `pass`.
