# M1 evaluation fixtures

This directory contains original, author-created bootstrap data for the local `NiceSwitcherEvaluate` CLI:

- `Corpus/tuning.jsonl` and `Corpus/held-out.jsonl` contain synthetic single-token examples. `expectedText: null` means preserve the input; every row includes an explicit label.
- `Layouts/fixtures.json` contains synthetic US QWERTY and Russian JCUKEN output maps keyed by physical key code and modifier. The IDs begin with `fixture.` and are not Apple input-source identifiers or verified macOS keyboard tables.
- `Lexicon/baseline.json` contains a small hand-authored frequency table. It is fixed with the examples and is not a production dictionary.

All records, mappings, and lexicon entries are original synthetic fixtures released under MIT; no third-party or user text is included. See the repository-root [`provenance.json`](../provenance.json) and [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

Run the evaluation from the repository root with:

```sh
swift run NiceSwitcherEvaluate --data-dir Data
```

The held-out split is separated from tuning groups and lexical forms, but the corpus is small and synthetic. It is an engineering smoke test for the evaluation pipeline, not an independent or representative user study. Do not infer the M1 quality targets or support for real Apple layouts from these fixtures.
