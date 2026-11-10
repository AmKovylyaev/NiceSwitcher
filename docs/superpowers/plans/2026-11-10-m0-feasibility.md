# M0: стенд проверки Undo/Redo — Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development. Выполнять только назначенную задачу; обязательны проверка основным агентом и возврат ошибок исполнителю.

**Goal:** Подготовить небольшой воспроизводимый стенд для живой проверки замены выбранного синтетического слова через AX в редакторах macOS.

**Architecture:** Swift Package с переносимым модулем ProbeCore и CLI NiceSwitcherProbe. macOS-адаптер CLI работает через публичные Accessibility API, с явно указанным bundle ID и выбранным тестовым словом. Это исследовательский инструмент, а не фоновый NiceSwitcher и не доказанная реализация R8.

**Tech Stack:** Swift 6.0 language/tools minimum, SwiftPM, XCTest, Foundation; AppKit/ApplicationServices/Carbon только под `#if os(macOS)`. Технический deployment floor стенда macOS 13, без утверждения поддержки этой ОС продуктом.

**Spec:** `docs/mac-layout-switcher-requirements.md`, утверждённый маршрут `docs/reviews/2026-11-10-implementation-review.md`.

## Global Constraints

- Всё распознавание, обучение и хранение выполняется на Mac; runtime-сети нет.
- R8: исправление — одна отдельная операция в штатной истории редактора, включая меню, дальнейший ввод, Redo и работу после завершения свитчера.
- Успех AX-вызова не доказывает R8. Непроведённые испытания помечаются `not_run`.
- Не перехватывать ⌘Z, не создавать внешний UndoBroker, не удерживать ввод и не использовать clipboard.
- Стенд изменяет только явно выбранное синтетическое слово и только после точного совпадения с `--expected` в указанном `--bundle-id`.
- Не устанавливать input method, фоновые службы или системные разрешения автоматически.
- Не читать весь документ; selected text допускается только для проверки тестовой операции и не выводится в лог.
- Отчёты Mac/личные данные хранятся в игнорируемом `artifacts/`, не публикуются автоматически.
- Исполнитель: `gpt-6-luna`, reasoning `max`; никаких дочерних агентов.

## Review Focus

1. Переключение приложения/поля между снимком и записью: отказ, без повторной вставки.
2. Secure input, secure subrole, неизвестная роль/атрибуты: отказ.
3. Emoji/составные символы: диапазоны именно UTF-16; сравнение selected text точное.
4. Аргументы CLI: отсутствие/дублирование/неизвестные флаги, NaN/Infinity/отрицательная задержка, пустой исходный текст — ошибка до записи.
5. AX-success не превращается в `passed` для Undo; в шаблонах нет выдуманных результатов или утверждения о совместимости.

## Task 1: воспроизводимый исследовательский стенд

**Files:**
- Create: `Package.swift`.
- Create: `Sources/ProbeCore/ProbeCommand.swift`, `Sources/ProbeCore/SelectionSafety.swift`.
- Create: `Sources/NiceSwitcherProbe/main.swift`; небольшой macOS-адаптер можно вынести в соседний файл.
- Create: `Tests/ProbeCoreTests/ProbeCommandTests.swift`, `Tests/ProbeCoreTests/SelectionSafetyTests.swift`.
- Create: `docs/validation/m0-runbook.md`, `docs/validation/compatibility-matrix.md`, `docs/validation/m0-status.md`.
- Create: `.github/workflows/swift.yml`.
- Modify: `README.md` (добавить точные команды и статус стенда).

**Interfaces:**
- `ProbeCommand.parse(_ arguments: [String]) throws -> ProbeCommand` с командами `inspect --bundle-id ID --delay SECONDS` и `replace-selected --bundle-id ID --expected TEXT --replacement TEXT --delay SECONDS`.
- `SelectionSnapshot`: bundle ID, AX role/subrole, enabled flag, secure input flag, selected text, UTF-16 range location/length, selected-text writability. Отсутствующие данные представляются как неизвестные и запрещают запись.
- `SelectionSafety.validate(_ snapshot: SelectionSnapshot, expectedBundleID: String, expectedText: String) throws`.
- CLI exit code 0 для успешно выполненной inspect/AX-попытки, ненулевой для отказа/неподдерживаемой платформы. Успешная попытка имеет статус `write_accepted_unverified`, никогда `undo_passed`.

- [x] **Step 1: написать тесты парсинга и безопасности до реализации.** Проверить команды, точное совпадение ожидаемого слова, bundle ID, разрешённые AXTextField/AXTextArea роли, secure subrole, disabled/unknown поля, отрицательные/переполненные диапазоны, несовпадение UTF-16 длины, неизвестную writability. Парсер отклоняет дубли/неизвестные флаги, NaN/Infinity, delay вне 0...30, пустые аргументы и слишком длинные строки (лимит исходного/нового слова 64 grapheme clusters, без переводов строки).
- [x] **Step 2: запустить `swift test`, зафиксировать ожидаемый RED.** Первичная ошибка отсутствующего интерфейса допустима при заведении пакета; затем тесты должны проверять содержательное поведение, а не только компиляцию.
- [x] **Step 3: реализовать переносимое ядро и добиться GREEN.** SwiftPM package не требует внешних зависимостей, сетевого runtime или скачивания словарей.
- [x] **Step 4: реализовать macOS AX-попытку.** Проверить AXIsProcessTrusted, secure input, frontmost bundle ID и focused UI element. Считать только роль/подроль, enabled, selected text/range и settable AXSelectedText. Перед записью повторно получить фокус/снимок и сравнить поле через CFEqual и все значимые данные. Менять только AXSelectedText, ровно один раз. Не использовать AXValue как fallback, не нажимать клавиши и не менять clipboard/input source. Ошибка или неизвестный результат не вызывает retry. CLI не логирует текст. Локальная повторная проверка не заявляется атомарной транзакцией.
- [x] **Step 5: документировать живую проверку.** `m0-runbook.md` содержит установку Xcode Command Line Tools самим пользователем, `swift --version`, `swift test`, `swift build`, проверку разрешения Accessibility и запуск CLI. Пользователь выбирает только синтетический текст, заранее набранный в отдельной заметке/несохранённом черновике; никаких отправок форм/писем. Указать команды с bundle IDs, задержкой 5 секунд и выделением только `ghbdtn`, без пробела. Объяснить, что автоматическое выделение/наблюдение ввода ещё не реализовано.
- [x] **Step 6: оформить матрицу и статус.** Целевые поверхности: Notes plain/list/rich, Mail body, Safari и Chrome input/textarea/contenteditable/Google/ChatGPT, native ChatGPT. Для каждой указать `not_run` по U1–U10, S1/S3/S5, а также наблюдаемости отмены C vs B, Redo, меню и ручного исправления. Состояния: not_run/pass/fail/blocked, обязательные OS build/SDK/app version/field type/mechanism/evidence. Не ставить pass автоматически. Различать ручное наблюдение человеком и доступность машинного feedback. Честно перечислить, что AX-проба проверяет лишь один кандидат и не закрывает другие механизмы и production safety.
- [x] **Step 7: CI и проверка.** Workflow macos-15, `permissions: contents: read`, checkout action pinned SHA, `swift --version`, `xcodebuild -version`, `swift test`, `swift build -c release`. CI не выдаётся за живую совместимость. На Linux `swift test` проверяет переносимую часть, запуск CLI явно отказывается от AX-операции.
- [x] **Step 8: самопроверка и коммит.** `swift test`, `swift build -c release`, `git diff --check`. Отчёт в `.superpowers/sdd/m0/task-1-report.md`: RED/GREEN, команды и реальные результаты, SHA, что нельзя проверить. Финальный ответ исполнителя короткий: статус/коммиты/проверки/ограничения.

## Task 2: живые испытания на Mac (основной агент + пользователь)

**Files:** результаты пользователя в `artifacts/`, обезличенный итог в `docs/validation/m0-status.md` после согласования фактических данных.

**Interfaces:** использует CLI и runbook Task 1; не меняет их поведение ради прохождения сценариев.

- [ ] Проверить сборку macOS; записать версии ОС/build/SDK/редакторов и источников ввода.
- [ ] Пройти матрицу U1–U10 для каждого заявляемого адаптера; проверить границы групп, форматирование, emoji, меню и завершение CLI до Undo/Redo.
- [ ] Отдельно выяснить, каким публичным механизмом приложение может достоверно коррелировать C/B/Redo/ручную перепечатку; ручная видимость результата человеком не доказывает машинную наблюдаемость.
- [ ] При провале AX-кандидата записать воспроизводимый результат; подготовить отдельный сравнительный план input method/интеграций. Не устанавливать их молча.
- [ ] Закрывать M0 только по фактическому исследованию; без доступа к Mac Task 2 остаётся blocked. Независимый M1 разрешён утверждённым маршрутом, M2 с автозаменами — нет.
