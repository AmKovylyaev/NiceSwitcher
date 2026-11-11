# M1 synthetic baseline

The research evaluator and its fixed input data are committed at `da83e6d42bff402c1624d2bf5d33034943e186d4`. Run the baseline from the repository root with Swift 6.1.2 on Linux:

```sh
PATH=/workspace/toolchains/swift-6.1.2-RELEASE-ubuntu24.04/usr/bin:$PATH \
CLANG_MODULE_CACHE_PATH=/tmp/niceswitcher-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/tmp/niceswitcher-swift-cache \
XDG_CACHE_HOME=/tmp/niceswitcher-cache \
XDG_CONFIG_HOME=/tmp/niceswitcher-config \
swift run NiceSwitcherEvaluate --data-dir Data
```

The command loads the JSONL corpus, fixture layouts, and lexicon, validates every record, then invokes the production `Detector` for each token. It uses an empty exception set and performs no training or network access. The JSON output includes row and distinct group counts, aggregate counts, category counts, and rates; a zero denominator is encoded as `null`.

| Split | Rows | Distinct groups | Preserve tokens | Error tokens | False corrections | Corrected errors | Missed | Wrong | Abstentions | False-correction rate | Error recall |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Tuning | 20 | 20 | 10 | 10 | 0 | 10 | 0 | 0 | 10 | 0/10 (0%) | 10/10 (100%) |
| Held-out | 80 | 80 | 32 | 48 | 1 | 48 | 0 | 0 | 31 | 1/32 (3.125%) | 48/48 (100%) |

Category row counts were: tuning — clear-error 10, ambiguous 2, name 2, abbreviation 2, technical 2, mixed-script 1, protected 1; held-out — clear-error 48, ambiguous 6, name 6, abbreviation 5, technical 5, mixed-script 5, protected 5. The lexicon has 33 English and 34 Russian entries, all with hand-assigned positive frequency 1.

The single held-out false correction is the fixed hard negative `Tim` → `Ешь`: the US source lexicon does not contain `Tim`, while the Russian target lexicon contains `ешь`. The row is labeled preserve and includes its physical key trace. The baseline therefore counts this limitation rather than hiding it by changing the detector or dictionary.

The fixture maps are synthetic. After an initial evaluation exposed that ordinary typed names and identifiers should carry physical traces, I added traces for representable name, abbreviation, and technical-token preserves. I also added the ten base digit outputs (`1`–`0`) to both fixture profiles so the existing `UTF8` preserve example has a complete trace. All pre-existing layout outputs remained unchanged; labels and lexicon were not changed, and the detector was not changed. The final counts above are from the committed data with those traces and layout entries.

This bootstrap corpus is small and author-created; its one-row-per-group counts do not make it a representative or independent user study. The held-out false-correction rate is 3.125% on these 32 synthetic preserves, so this run does not demonstrate the M1 target of at most 1 false correction per 1,000 correct tokens. The 48/48 error recall only describes these deliberately supported fixture examples. The fixture IDs and output maps are not verified Apple input-source identifiers or live macOS layouts. Production dictionaries, licensed external data, real layout tables, and independent user evaluation remain open work.

All corpus, layout, and lexicon fixtures are original synthetic material under the repository MIT license; no third-party or user text is included. See [`Data/README.md`](../../Data/README.md), [`provenance.json`](../../provenance.json), and [`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md).
