# Dictionary Tooling

This folder contains proof-of-concept tooling for evaluating offline dictionary
sources for Quick Look Mode. Nothing here is bundled into the iOS app target.

## CC-CEDICT

CC-CEDICT can be downloaded from the MDBG CC-CEDICT page:

https://www.mdbg.net/chinese/dictionary?page=cedict

The downloadable file is a Chinese to English dictionary. It is useful as a
fallback lookup and segmentation source for the Quick Look Chinese to English
overlay.

## License Note

CC-CEDICT is licensed under Creative Commons Attribution-ShareAlike 4.0
International. If we later bundle data derived from CC-CEDICT, the app must
include attribution and preserve the share-alike obligations for adapted
dictionary data.

This proof-of-concept writes a `licenseSource` field with:

`CC-CEDICT CC BY-SA`

## Convert A Sample

Download and extract CC-CEDICT somewhere outside the app project, then run:

```sh
python3 tools/dictionaries/convert_cc_cedict_sample.py /path/to/cedict_ts.u8
```

By default the script exports only the current Quick Look sample terms:

```text
购物车,支付,发货,包装,仓库,国际运输,高跟鞋,优惠券,退款,地址,标签,外箱,货物,运输,木架,入仓费,私人仓
```

To provide a custom sample set:

```sh
python3 tools/dictionaries/convert_cc_cedict_sample.py /path/to/cedict_ts.u8 \
  --terms "购物车,支付,发货"
```

To choose the SQLite output path:

```sh
python3 tools/dictionaries/convert_cc_cedict_sample.py /path/to/cedict_ts.u8 \
  --output /tmp/QuickLookCEDICTSample.sqlite
```

To export every valid CC-CEDICT entry for local experimentation:

```sh
python3 tools/dictionaries/convert_cc_cedict_sample.py /path/to/cedict_ts.u8 \
  --all --output /tmp/QuickLookCEDICTFull.sqlite
```

Do not add generated SQLite files to app resources until we deliberately choose
a dictionary source, storage format, attribution screen, and lookup strategy.

## Test Quick Look Lookup Ranking

After generating a sample or full CC-CEDICT SQLite database, run the lookup
pipeline experiment:

```sh
python3 tools/dictionaries/test_quicklook_lookup_pipeline.py \
  /tmp/QuickLookCEDICTSample.sqlite
```

The experiment simulates the intended future Quick Look Chinese to English
dictionary order:

1. app-owned phrase and pattern overrides for common app UI text;
2. CC-CEDICT exact Chinese to English lookup;
3. CC-CEDICT segmented Chinese to English fallback;
4. skip if no useful compact English label is available.

To test custom OCR phrases, pass a pipe-separated list:

```sh
python3 tools/dictionaries/test_quicklook_lookup_pipeline.py \
  /tmp/QuickLookCEDICTSample.sqlite \
  --phrases "购物车|优惠券|私人仓，无入仓费"
```

Or provide one phrase per line:

```sh
python3 tools/dictionaries/test_quicklook_lookup_pipeline.py \
  /tmp/QuickLookCEDICTSample.sqlite \
  --terms-file /tmp/ocr_phrases.txt
```

`--phrases-file` is also accepted as an alias for `--terms-file`.

For machine-readable inspection:

```sh
python3 tools/dictionaries/test_quicklook_lookup_pipeline.py \
  /tmp/QuickLookCEDICTSample.sqlite \
  --json
```

## Full CC-CEDICT Coverage Experiment

Generate a full local SQLite database in `/tmp` only:

```sh
python3 tools/dictionaries/convert_cc_cedict_sample.py \
  /tmp/screentranslator-cedict-poc/cedict_ts.u8 \
  --all \
  --output /tmp/screentranslator-cedict-poc/QuickLookCEDICTFull.sqlite
```

Then run the realistic OCR-miss fixture:

```sh
python3 tools/dictionaries/test_quicklook_lookup_pipeline.py \
  /tmp/screentranslator-cedict-poc/QuickLookCEDICTFull.sqlite \
  --phrases-file tools/dictionaries/fixtures/real_ocr_misses.txt
```

The lookup experiment reports:

- total phrases;
- phrases covered by app-owned phrase overrides;
- phrases covered by CC-CEDICT exact or segment fallback;
- skipped phrases;
- dictionary load and analysis time.

This proves whether a layered phrase-rule plus CC-CEDICT fallback can improve
OCR phrase coverage before any runtime app code or bundled resources are
changed.

Generated SQLite files are not app resources. If we later bundle CC-CEDICT or a
derived subset, the app must include attribution and comply with CC BY-SA
share-alike obligations for the dictionary data.

## Reduced CC-CEDICT Subset Experiment

The full CC-CEDICT database is useful for coverage testing, but raw fallback
labels can be noisy in a small screenshot overlay. Build an experimental reduced
subset in `/tmp`:

```sh
python3 tools/dictionaries/build_cc_cedict_reduced_subset.py \
  --input /tmp/screentranslator-cedict-poc/QuickLookCEDICTFull.sqlite \
  --output /tmp/screentranslator-cedict-poc/QuickLookCEDICTReduced.sqlite
```

The reducer keeps entries related to shopping, payment, refunds, shipping,
logistics, warehouse, packaging, product details, price, coupons, common UI
actions, and seller chat. It rejects most single-character entries, common
function words, very long definitions, broad grammar terms, and known noisy
matches such as `点`.

Evaluate the reduced subset against the current OCR-miss fixture:

```sh
python3 tools/dictionaries/test_quicklook_lookup_pipeline.py \
  --cedict-db /tmp/screentranslator-cedict-poc/QuickLookCEDICTReduced.sqlite \
  --phrases-file tools/dictionaries/fixtures/real_ocr_misses.txt
```

The reduced subset is still experimental and is intended only as an English
fallback after app-owned phrase rules. It is not bundled into the app. If a
derived subset is bundled later, CC-CEDICT attribution and CC BY-SA share-alike
obligations still need to be handled.

## General CC-CEDICT Overlay Subset Experiment

The general subset experiment is broader than the shopping/logistics reducer.
It targets common Chinese app and website UI: actions, login, errors, chat,
payment, logistics, forms, time/date, location, food/services, and general
high-frequency app words.

Build the general candidate database in `/tmp`:

```sh
python3 tools/dictionaries/build_cc_cedict_general_subset.py \
  --input /tmp/screentranslator-cedict-poc/QuickLookCEDICTFull.sqlite \
  --output /tmp/screentranslator-cedict-poc/QuickLookCEDICTGeneral.sqlite \
  --json-output /tmp/screentranslator-cedict-poc/QuickLookCEDICTGeneral.json
```

This output stores both raw CC-CEDICT definitions and compact display labels:

- `englishRaw`: original converted CC-CEDICT definition text;
- `englishDisplay`: shortened overlay label;
- `category`: broad app category used during selection.

Evaluate it against both fixtures:

```sh
python3 tools/dictionaries/test_quicklook_lookup_pipeline.py \
  --cedict-db /tmp/screentranslator-cedict-poc/QuickLookCEDICTGeneral.sqlite \
  --phrases-file tools/dictionaries/fixtures/real_ocr_misses.txt

python3 tools/dictionaries/test_quicklook_lookup_pipeline.py \
  --cedict-db /tmp/screentranslator-cedict-poc/QuickLookCEDICTGeneral.sqlite \
  --phrases-file tools/dictionaries/fixtures/general_app_phrases.txt
```

The general subset is still an English fallback after app-owned phrase rules. It
is not bundled into the app. If bundled later, CC-CEDICT attribution and CC
BY-SA share-alike obligations must be handled.

## CN to EN Finalization Pass

The first Chinese to English quality finalization pass adds app-owned phrase and
pattern rules before CC-CEDICT matching. These rules handle common app phrases
such as `对方正在输入`, `暂无数据`, `地铁路线`, `退出登录`, `支付失败`, and
the numeric pattern `<number>点抢` without globally allowing noisy `点` matches.

Generate the v2 candidate in `/tmp`:

```sh
python3 tools/dictionaries/build_cc_cedict_general_subset.py \
  --input /tmp/screentranslator-cedict-poc/QuickLookCEDICTFull.sqlite \
  --output /tmp/screentranslator-cedict-poc/QuickLookCEDICTGeneral_v2.sqlite \
  --json-output /tmp/screentranslator-cedict-poc/QuickLookCEDICTGeneral_v2.json
```

Evaluate it:

```sh
python3 tools/dictionaries/test_quicklook_lookup_pipeline.py \
  --cedict-db /tmp/screentranslator-cedict-poc/QuickLookCEDICTGeneral_v2.sqlite \
  --phrases-file tools/dictionaries/fixtures/general_app_phrases.txt
```

The generated v2 database preserves source metadata per row:

- CC-CEDICT rows keep `sourceKind = cc_cedict` and
  `licenseSource = CC-CEDICT CC BY-SA 4.0`;
- app-owned phrase rows use `sourceKind = app_phrase_override`.

CC-CEDICT is CC BY-SA. If any generated subset is bundled, attribution is
required and share-alike obligations may apply to the derived dictionary data.
The source/provenance metadata should remain in the generated database. This is
not legal advice.

## Runtime Prototype Note

`QuickLookCEDICTGeneral_v2.sqlite` is the current runtime prototype candidate
for Chinese to English Quick Look fallback lookup. It is a derived CC-CEDICT
subset plus app-owned phrase overrides. Before App Store shipment, the app needs
an explicit attribution/share-alike plan for the bundled derived database. Keep
the `sourceKind` and `licenseSource` columns intact when regenerating it.
