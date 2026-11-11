# M0 compatibility matrix

No live macOS editor test has been run in this environment. Every behavior cell starts as `not_run`; no surface is declared compatible. Each run must record the macOS build, SDK, app version, field type, mechanism, and evidence. Human observation and machine feedback are separate because the probe does not observe later Undo/Redo activity.

`U1–U10` refers to the acceptance scenarios in the project requirements. `C` is the candidate replacement and `B` is a later ordinary edit.

| Surface and field | U1–U10 | S1 | S3 | S5 | C vs B observed by human | C/B machine feedback | Redo | Undo/Redo menu | Manual correction | macOS build | SDK | App version | Field type | Mechanism | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Apple Notes — plain text | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | plain text | AXSelectedText candidate; not_run | none |
| Apple Notes — list | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | list item | AXSelectedText candidate; not_run | none |
| Apple Notes — rich text | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | formatted text | AXSelectedText candidate; not_run | none |
| Apple Mail — message body | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | body editor | AXSelectedText candidate; not_run | none |
| Safari — ordinary input | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | input | AXSelectedText candidate; not_run | none |
| Safari — textarea | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | textarea | AXSelectedText candidate; not_run | none |
| Safari — contenteditable | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | contenteditable | AXSelectedText candidate; not_run | none |
| Safari — Google Search | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | search field | AXSelectedText candidate; not_run | none |
| Safari — ChatGPT field | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | chat field | AXSelectedText candidate; not_run | none |
| Chrome — ordinary input | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | input | AXSelectedText candidate; not_run | none |
| Chrome — textarea | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | textarea | AXSelectedText candidate; not_run | none |
| Chrome — contenteditable | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | contenteditable | AXSelectedText candidate; not_run | none |
| Chrome — Google Search | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | search field | AXSelectedText candidate; not_run | none |
| Chrome — ChatGPT field | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | chat field | AXSelectedText candidate; not_run | none |
| Native ChatGPT for macOS — composer | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_run | not_recorded | not_recorded | not_recorded | chat composer | AXSelectedText candidate; not_run | none |

The U1–U10 cell is an aggregate: mark it `pass` only when all ten cases have individual `pass` statuses and evidence in the per-run template in the runbook for that same app/version/field. Any missing, blocked, or failed case keeps the aggregate from passing.

The matrix covers only the AX selected-text candidate. It does not test input methods or another integration mechanism, and it does not prove R8, undo observation, production safety, or compatibility beyond the exact recorded OS/app/field combination.
