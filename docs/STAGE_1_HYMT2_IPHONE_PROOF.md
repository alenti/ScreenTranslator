# Stage 1 — Hy-MT2 Q4 Real-iPhone Proof

Final verdict: **NO-GO QUALITY**. This is the observer-free acceptance run completed at 2026-08-20T05:59:37.656Z; the full raw payload, including Base64 output bytes and backend log, is in the companion JSON.

## 1. Git state before/after

- Before: branch `main`, HEAD `19d01e24aadd45847b277c2626308927a4cc3638`; 16 files changed, 3887 insertions(+), 243 deletions(-).
- Before modified tracked files:
  - `Features/Settings/SettingsView.swift`
  - `Intents/QuickLook/QuickLookDiagnosticsModels.swift`
  - `Intents/QuickLook/QuickLookDiagnosticsRenderer.swift`
  - `Intents/QuickLook/QuickLookEnglishTranslationProvider.swift`
  - `Intents/QuickLook/QuickLookLocalMTClient.swift`
  - `Intents/QuickLook/QuickLookLocalMTConfig.swift`
  - `Intents/QuickLook/QuickLookLocalMTTranslationProvider.swift`
  - `Intents/QuickLook/QuickLookMTBlockPreparer.swift`
  - `Intents/QuickLook/QuickLookOCRBlockMapper.swift`
  - `ScreenTranslator.xcodeproj/project.pbxproj`
  - `tools/opus_mt_server/README.md`
  - `tools/opus_mt_server/models/opus-mt-zh-en-ct2/model.bin`
  - `tools/opus_mt_server/opus_mt_engine.py`
  - `tools/opus_mt_server/requirements.txt`
  - `tools/opus_mt_server/server.py`
  - `tools/opus_mt_server/translate_cli.py`
- Before untracked project entries included:
  - `.gitignore`
  - `Config/`
  - `Core/Services/OnDeviceMT/`
  - `Features/OnDeviceMT/`
  - `LocalLlama/`
  - `LocalModels/`
  - `ScreenTranslator-Bridging-Header.h`
  - `docs/`
  - `tools/on_device_llama/`
  - `tools/opus_mt_server development files`
- Stage 1 files already contained user work: **yes**. Changes were merged into current contents.
- After: branch and HEAD unchanged; 17 files changed, 3934 insertions(+), 244 deletions(-). Existing untracked work remains present.
- No commit, push, branch creation, reset, clean, stash, or checkout-over operation was performed.

## 2. Every Stage 1 file changed

- `Config/OnDeviceLlamaBridge.xcconfig`
- `Core/Services/OnDeviceMT/Native/Stage1HyMTBridge.h`
- `Core/Services/OnDeviceMT/Native/Stage1HyMTBridge.mm`
- `Features/OnDeviceMT/Stage1HyMTBenchmark.swift`
- `Features/Settings/SettingsView.swift`
- `ScreenTranslator-Bridging-Header.h`
- `ScreenTranslator.xcodeproj/project.pbxproj`
- `ScreenTranslatorApp.swift`
- `tools/on_device_llama/build_stage1_hymt2_xcframework.sh`
- `tools/on_device_llama/embed_stage1_llama_framework.sh`
- `tools/on_device_llama/install_stage1_model.sh`
- `tools/on_device_llama/stage1_jinja_renderer.cpp`
- `tools/on_device_llama/stage1_jinja_renderer.h`
- `tools/on_device_llama/stage1_jinja_renderer_test.cpp`
- `docs/STAGE_1_HYMT2_IPHONE_PROOF.md`
- `docs/benchmarks/stage1_hymt2_q4_2026-08-20T05-59-37-656Z.json`

The GGUF, XCFramework, static Jinja library, build directories, and device poll artifacts remain outside Git. No production translation implementation was refactored or deleted.

## 3. Model repository/revision/SHA/size

- Repository: https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF
- Revision: `1cd5208700acedef4ef93019b6cfc148b8522d45`
- File: `Hy-MT2-1.8B-Q4_K_M.gguf`
- Size: 1133080448 bytes; expected 1133080448; **PASS**
- SHA-256: `dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699`; **PASS**
- Git/LFS: model is not committed.

## 4. llama.cpp revision

- Commit: `b062ba735e5e15817f6a1dbdb84717ee3097f619`
- Source tarball SHA-256: `67fd3fee8559c3db276219f0ca22fe8b985c965c690d90c718d33f8ff44034d4`
- No implicit `master` tracking.
- Source/audit difference: pinned `llama_chat_apply_template` is explicitly a predefined-template helper, not a full Jinja parser. The official iOS build disables `llama-common`, so Stage 1 builds only the pinned upstream `common/jinja` lexer/parser/runtime as an optimized static companion. The self-check verifies Hy role-token order.

## 5. XCFramework/build configuration

- Official command: `./build-xcframework.sh ios-device ios-sim`
- Native build: Release optimized; app harness: Debug only.
- Compiler: Apple clang 21.0.0; Xcode 26.6; CMake 4.3.2.
- Flags: `BUILD_SHARED_LIBS=OFF`, `GGML_METAL=ON`, `GGML_METAL_EMBED_LIBRARY=ON`, `GGML_BLAS_DEFAULT=ON`, `GGML_OPENMP=OFF`, `GGML_NATIVE=OFF`.
- Slices: iOS arm64; simulator arm64/x86_64.
- XCFramework checksum: `6a70dde110b62178c05b92232e45846ef50f01ada42d1b149960864b4a2b71b0`; build date 2026-08-20T05:24:31Z.
- Pinned Jinja library checksum: `72b80f0cedde577e3f75da3a44fe50d603951d4e809bda5b9d694e119188b374`.
- Two clean official XCFramework builds completed. Final simulator build, signed physical build, deep code-sign verification, and real-device benchmark passed.
- Release does not depend on local developer paths; the dynamic framework embed phase exits outside Debug.

## 6. Real iPhone identity/iOS

- Device: iPhone 13 Pro Max; hardware `iPhone14,3`; A15 Bionic (derived from public hardware identifier).
- Physical memory: 5915164672 bytes.
- iOS: Version 26.5 (Build 23F77).
- Build: Debug app / Release-optimized llama.cpp.
- Low Power Mode: false; initial thermal state: fair; available storage: 14656424596 bytes.
- Device name, serial, and UDID are not hard-coded or reported.

## 7. Metal/backend proof

- Backend initialization: 5.91 ms.
- Metal enumerated: true; GPU offload supported: true; offload log confirmed: true.

```text
ggml_metal_library_init: using embedded metal library
ggml_metal_library_init: loaded in 0.039 sec
ggml_metal_device_init: GPU name:   MTL0 (Apple A15 GPU)
load_tensors: loading model tensors, this can take a while... (load_mode = mmap)
load_tensors: offloaded 33/33 layers to GPU
load_tensors:   CPU_Mapped model buffer size =   193.57 MiB
load_tensors:  MTL0_Mapped model buffer size =  1075.74 MiB
llama_kv_cache:       MTL0 KV buffer size =   128.00 MiB
sched_reserve:       MTL0 compute buffer size =    60.99 MiB
sched_reserve:        CPU compute buffer size =     2.50 MiB
```

The first-ever runtime preflight took 22092.20 ms because the embedded Metal library initialized in 20.280 s. Its translations are excluded because that run exposed the template-helper bug. In the accepted run, the first load+context took 2486.42 ms with Metal already cached.

## 8. Runtime configuration and template

- `n_ctx=2048`, `n_batch=256`, `n_ubatch=128`, four CPU threads, `n_gpu_layers=-1`, mmap enabled, one model/context, serialized generation.
- Template engine: `llama.cpp common/jinja parser+runtime @ b062ba735e5e15817f6a1dbdb84717ee3097f619`.
- Embedded Jinja template: `{% if messages[0]['role'] == 'system' %}{% set loop_messages = messages[1:] %}{% set system_message = messages[0]['content'] %}<｜hy_begin▁of▁sentence｜>{{ system_message }}<｜hy_place▁holder▁no▁3｜>{% else %}{% set loop_messages = messages %}<｜hy_begin▁of▁sentence｜>{% endif %}{% for message in loop_messages %}{% if message['role'] == 'user' %}<｜hy_User｜>{{ message['content'] }}{% elif message['role'] == 'assistant' %}<｜hy_Assistant｜>{{ message['content'] }}<｜hy_place▁holder▁no▁2｜>{% endif %}{% endfor %}{% if add_generation_prompt %}<｜hy_Assistant｜>{% else %}<｜hy_place▁holder▁no▁8｜>{% endif %}`.
- Applied prompt proof: `<｜hy_begin▁of▁sentence｜><｜hy_User｜>Translate the following text into English. Note that you should only output the translated result without any additional explanation:<br>加入购物车<｜hy_Assistant｜>`.
- Generation ends on model EOG; no guessed string stops, dictionaries, semantic repair, phrase correction, explanation stripping, or CJK replacement.
- Memory sampling occurs only outside the timed token loop; generation time includes sampling, token decoding, and Metal decode, while `decodeMs` is backend compute only.

## 9. Sampling A/B and manual quality

- Official: temperature 0.7, top-p 0.6, top-k 20, repeat penalty 1.05, seed 20260820.
- Greedy: fixed seed 20260820.

| Target / sampling | Reviewed acceptance | Rate |
|---|---:|---:|
| English / official | 17/18 | 94.44% |
| English / greedy | 17/18 | 94.44% |
| Russian / official | 15/18 | 83.33% |
| Russian / greedy | 16/18 | 88.89% |

- Overall reviewed acceptance: 65/72 (90.28%).
- English: 17/18 (94.44%) for each strategy; Russian: official 15/18 (83.33%), greedy 16/18 (88.89%).
- Critical reversals: 2 generation rows / 1 unique source case. Invented action: 1. Target-language violations: 2.
- Protected data: 66/72; all six failures are Russian unit-form changes such as `3000K→3000К` and `260×80cm→260×80 см`.
- Chinese residue: 0; prompt leakage: 0; max-token terminations: 0; native errors: 0.
- Greedy had fewer reviewed failures than official but still fails the gates; no production sampling strategy is selected.

## 10–11. English and Russian raw outputs

Only tokenizer decoding, EOG termination, and outer-whitespace trimming were allowed. `rawOutputBase64` in JSON preserves the raw bytes.

| Case | Target | Sampling | Source | Raw output | Protected | Manual review | Total ms |
|---|---|---|---|---|---|---|---:|
| basic_add_to_cart | English | official | 加入购物车 | Add to cart | PASS | PASS | 245.09 |
| basic_add_to_cart | English | greedy | 加入购物车 | Add to cart | PASS | PASS | 245.59 |
| basic_add_to_cart | Russian | official | 加入购物车 | Добавить в корзину | PASS | PASS | 450.90 |
| basic_add_to_cart | Russian | greedy | 加入购物车 | Добавить в корзину | PASS | PASS | 441.25 |
| basic_buy_now | English | official | 立即购买 | Buy now | PASS | PASS | 198.87 |
| basic_buy_now | English | greedy | 立即购买 | Buy now | PASS | PASS | 197.92 |
| basic_buy_now | Russian | official | 立即购买 | Купите сейчас | PASS | PASS | 374.41 |
| basic_buy_now | Russian | greedy | 立即购买 | Купить сейчас | PASS | PASS | 360.66 |
| basic_deliver_to | English | official | 配送至 | Delivery to | PASS | PASS | 199.20 |
| basic_deliver_to | English | greedy | 配送至 | Delivery to | PASS | PASS | 200.79 |
| basic_deliver_to | Russian | official | 配送至 | Доставка до | PASS | PASS | 285.87 |
| basic_deliver_to | Russian | greedy | 配送至 | Доставка до | PASS | PASS | 279.51 |
| basic_contact_service | English | official | 联系客服 | Contact customer service | PASS | PASS | 243.45 |
| basic_contact_service | English | greedy | 联系客服 | Contact customer service | PASS | PASS | 241.23 |
| basic_contact_service | Russian | official | 联系客服 | Свяжитесь с службой поддержки | PASS | PASS | 654.56 |
| basic_contact_service | Russian | greedy | 联系客服 | Свяжитесь с службой поддержки | PASS | PASS | 645.98 |
| basic_network_error | English | official | 网络错误，请重试 | Network error, please try again | PASS | PASS | 370.08 |
| basic_network_error | English | greedy | 网络错误，请重试 | Network error, please try again | PASS | PASS | 363.35 |
| basic_network_error | Russian | official | 网络错误，请重试 | Ошибка сети, пожалуйста, попробуйте снова | PASS | PASS | 1073.67 |
| basic_network_error | Russian | greedy | 网络错误，请重试 | Ошибка сети, пожалуйста, попробуйте снова | PASS | PASS | 1075.43 |
| options_lighting | English | official | 已选：暖白光 3000K，54W，260×80cm；20件 | Selected: Warm white light 3000K, 54W, 260×80cm; 20 pieces | PASS | PASS | 1165.60 |
| options_lighting | English | greedy | 已选：暖白光 3000K，54W，260×80cm；20件 | Selected: Warm white light 3000K, 54W, 260×80cm; 20 pieces | PASS | PASS | 1124.86 |
| options_lighting | Russian | official | 已选：暖白光 3000K，54W，260×80cm；20件 | Выбрано: теплый белый свет 3000 К, 54 Вт, размер 260×80 см; 20 штук | FAIL: 260×80cm, 3000K, 54W, 80cm | PASS | 1754.29 |
| options_lighting | Russian | greedy | 已选：暖白光 3000K，54W，260×80cm；20件 | Выбран: теплый белый свет 3000 К, 54 Вт, размер 260×80 см; 20 штук | FAIL: 260×80cm, 3000K, 54W, 80cm | PASS | 1758.92 |
| options_color | English | official | 颜色分类：奶油白 加厚款（含安装配件） | Color classification: Cream white, extra thick (includes installation accessories) | PASS | PASS | 755.67 |
| options_color | English | greedy | 颜色分类：奶油白 加厚款（含安装配件） | Color category: Cream white, extra thick (includes installation accessories) | PASS | PASS | 733.38 |
| options_color | Russian | official | 颜色分类：奶油白 加厚款（含安装配件） | Классификация цвета: кремово-белый, толстый вариант (включая комплект для установки) | PASS | PASS | 1815.95 |
| options_color | Russian | greedy | 颜色分类：奶油白 加厚款（含安装配件） | Классификация цвета: кремово-белый, толстый вариант (включая комплект для установки) | PASS | PASS | 1836.46 |
| logistics_packaging | English | official | 这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。 | This shipment will also be transported internationally later. Please ensure it is well-secured in packaging, and indicate the name of the goods on the outer box. | PASS | PASS | 1557.44 |
| logistics_packaging | English | greedy | 这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。 | This shipment will also be transported internationally later. Please ensure it is well-packed and indicate the item name on the outer box. | PASS | PASS | 1282.31 |
| logistics_packaging | Russian | official | 这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。 | Для этого груза в дальнейшем будет осуществлен международный транспорт. Пожалуйста, обеспечьте очень надежную упаковку и указывайте название груза на внешней коробке. | PASS | PASS | 2959.34 |
| logistics_packaging | Russian | greedy | 这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。 | Для этой партики товара будет дальнейший международный транспорт. Пожалуйста, обеспечьте очень надежную упаковку, и указывайте название товара на внешней коробке. | PASS | PASS | 2924.78 |
| seller_fault | English | official | 您好，我收到货后发现有一个灯不亮，可以补发配件吗？ | Hello, I found that one light does not work after receiving the item. Can you send me additional accessories? | PASS | PASS | 1916.48 |
| seller_fault | English | greedy | 您好，我收到货后发现有一个灯不亮，可以补发配件吗？ | Hello, I found that one light does not work after receiving the item. Can you send me the missing parts? | PASS | PASS | 2776.93 |
| seller_fault | Russian | official | 您好，我收到货后发现有一个灯不亮，可以补发配件吗？ | Здравствуйте, я получил товар, но обнаружил, что одна лампа не работает. Можем ли мы отправить дополнительные компоненты? | PASS | FAIL_CRITICAL_REVERSAL: asks whether 'we' can send parts instead of whether the seller can resend them | 3904.56 |
| seller_fault | Russian | greedy | 您好，我收到货后发现有一个灯不亮，可以补发配件吗？ | Здравствуйте, я получил товар, но обнаружил, что одна лампа не работает. Можем ли мы отправить дополнительные комплектующие? | PASS | FAIL_CRITICAL_REVERSAL: asks whether 'we' can send parts instead of whether the seller can resend them | 4065.81 |
| seller_reply | English | official | 可以的，麻烦拍一下故障视频，我们今天给您补发。 | Yes, please take a video of the malfunction. We will send it to you again today. | PASS | FAIL_MEANING: resend object becomes ambiguous pronoun 'it' after the fault-video request | 2105.99 |
| seller_reply | English | greedy | 可以的，麻烦拍一下故障视频，我们今天给您补发。 | Yes, please take a video of the malfunction. We will send it to you again today. | PASS | FAIL_MEANING: resend object becomes ambiguous pronoun 'it' after the fault-video request | 2082.68 |
| seller_reply | Russian | official | 可以的，麻烦拍一下故障视频，我们今天给您补发。 | Хорошо, пожалуйста, сфотографируйте видео с проблемой. Сегодня мы вышлем вам его вместе с компенсацией. | PASS | FAIL_HALLUCINATION: invents compensation and makes the replacement object ambiguous | 4392.21 |
| seller_reply | Russian | greedy | 可以的，麻烦拍一下故障视频，我们今天给您补发。 | Хорошо, пожалуйста, сфотографируйте видео с проблемой. Сегодня мы вышлем вам дополнительный экземпляр. | PASS | PASS | 7455.03 |
| spec_dimension | English | official | 260×80cm | 260×80cm | PASS | PASS | 689.20 |
| spec_dimension | English | greedy | 260×80cm | 260×80cm | PASS | PASS | 663.31 |
| spec_dimension | Russian | official | 260×80cm | 260×80 см | FAIL: 260×80cm, 80cm | PASS | 618.83 |
| spec_dimension | Russian | greedy | 260×80cm | 260×80 см | FAIL: 260×80cm, 80cm | PASS | 599.75 |
| spec_quantity | English | official | 20件 | 20 pieces | PASS | PASS | 457.48 |
| spec_quantity | English | greedy | 20件 | 20 pieces | PASS | PASS | 454.11 |
| spec_quantity | Russian | official | 20件 | 20 штук | PASS | PASS | 594.05 |
| spec_quantity | Russian | greedy | 20件 | 20 штук | PASS | PASS | 592.63 |
| spec_currency | English | official | ¥135 | ¥135 | PASS | PASS | 455.34 |
| spec_currency | English | greedy | ¥135 | ¥135 | PASS | PASS | 454.48 |
| spec_currency | Russian | official | ¥135 | ¥135 | PASS | PASS | 453.85 |
| spec_currency | Russian | greedy | ¥135 | ¥135 | PASS | PASS | 458.23 |
| spec_kelvin | English | official | 3000K | 3000K | PASS | PASS | 560.13 |
| spec_kelvin | English | greedy | 3000K | 3000K | PASS | PASS | 645.62 |
| spec_kelvin | Russian | official | 3000K | 3000К | FAIL: 3000K | PASS | 638.09 |
| spec_kelvin | Russian | greedy | 3000K | 3000К | FAIL: 3000K | PASS | 658.08 |
| spec_watts | English | official | 54W | 54W | PASS | PASS | 705.76 |
| spec_watts | English | greedy | 54W | 54W | PASS | PASS | 774.49 |
| spec_watts | Russian | official | 54W | 54W | PASS | PASS | 775.56 |
| spec_watts | Russian | greedy | 54W | 54W | PASS | PASS | 734.21 |
| mixed_apple | English | official | Apple MagSafe 兼容，型号 ST-54W，支持 USB-C | Compatible with Apple MagSafe, model ST-54W, supports USB-C | PASS | PASS | 2098.43 |
| mixed_apple | English | greedy | Apple MagSafe 兼容，型号 ST-54W，支持 USB-C | Compatible with Apple MagSafe, model ST-54W, supports USB-C | PASS | PASS | 2096.21 |
| mixed_apple | Russian | official | Apple MagSafe 兼容，型号 ST-54W，支持 USB-C | Соответствует Apple MagSafe, модель ST-54W, поддерживает USB-C | PASS | PASS | 2583.34 |
| mixed_apple | Russian | greedy | Apple MagSafe 兼容，型号 ST-54W，支持 USB-C | Совместим с Apple MagSafe, модель ST-54W, поддержка USB-C | PASS | PASS | 2230.44 |
| mixed_nike | English | official | Nike Air Max 黑色 42码 | Nike Air Max, Black, Size 42 | PASS | PASS | 1327.88 |
| mixed_nike | English | greedy | Nike Air Max 黑色 42码 | Nike Air Max Black, Size 42 | PASS | PASS | 1240.51 |
| mixed_nike | Russian | official | Nike Air Max 黑色 42码 | Nike Air Max, черный цвет, размер 42 | PASS | PASS | 1625.54 |
| mixed_nike | Russian | greedy | Nike Air Max 黑色 42码 | Nike Air Max, черный, размер 42 | PASS | PASS | 1457.89 |
| representative_paragraph | English | official | 这是一批准备发往海外仓的照明产品，共有20件。每件产品都需要单独套袋，并用加厚泡沫保护四角。装箱后请再次核对型号、数量和配件清单，确保外箱标签清晰、防水，避免在国际运输途中因挤压或受潮造成损坏。 | This is a batch of lighting products ready to be shipped to the overseas warehouse, consisting of 20 items in total. Each product needs to be placed in a separate bag and protected with thick foam at the corners. After packing, please check again the model numbers, quantities, and accessory lists to ensure that the outer box labels are clear and waterproof, so as to prevent damage due to compression or moisture during international transportation. | PASS | PASS | 7556.58 |
| representative_paragraph | English | greedy | 这是一批准备发往海外仓的照明产品，共有20件。每件产品都需要单独套袋，并用加厚泡沫保护四角。装箱后请再次核对型号、数量和配件清单，确保外箱标签清晰、防水，避免在国际运输途中因挤压或受潮造成损坏。 | This is a batch of lighting products ready to be shipped to the overseas warehouse, consisting of 20 items. Each product needs to be packed in a separate bag, and the four corners should be protected with thick foam. After packing, please check again the model numbers, quantities, and accessory lists to ensure that the outer boxes have clear labels and are waterproof, so as to prevent damage due to pressure or moisture during international transportation. | PASS | PASS | 7835.21 |
| representative_paragraph | Russian | official | 这是一批准备发往海外仓的照明产品，共有20件。每件产品都需要单独套袋，并用加厚泡沫保护四角。装箱后请再次核对型号、数量和配件清单，确保外箱标签清晰、防水，避免在国际运输途中因挤压或受潮造成损坏。 | Это набор осветительных изделий, предназначенных для отправки в офшорный склад; всего 20 единиц. Каждый изделие должно быть упаковано в отдельную упаковку и защищено толстым пенопластом от углов. После упаковки необходимо еще раз проверить модель, количество и список аксессуаров, чтобы etikеты на коробке были четкими и водонепроницаемыми, чтобы изделия не повредились в процессе международной доставки из-за сжатия или влаги. | PASS | FAIL_LANGUAGE_AND_MEANING: overseas warehouse becomes offshore warehouse and 'etikety' leaks in Latin script | 15754.54 |
| representative_paragraph | Russian | greedy | 这是一批准备发往海外仓的照明产品，共有20件。每件产品都需要单独套袋，并用加厚泡沫保护四角。装箱后请再次核对型号、数量和配件清单，确保外箱标签清晰、防水，避免在国际运输途中因挤压或受潮造成损坏。 | Это партия осветительных изделий, предназначенных для отправки в зарубежный склад, всего 20 единиц. Каждое изделие необходимо упаковать в отдельный пакет и защитить углы толстым пенопластом. После упаковки повторно проверьте модель, количество и список аксессуаров, чтобы обеспечить четкую и водонепроницаемую etику внешнего пакета, чтобы изделия не повредились из-за давления или влаги во время международной доставки. | PASS | FAIL_LANGUAGE_AND_MEANING: outer-box label becomes 'ethics' and the word contains a Latin-script prefix | 14633.70 |

## 12. Single-block versus micro-batch

| Target | Sampling | Prompt tok | Generated tok | Prefill ms | Generation ms | Decode compute ms | Micro total ms | Five singles total ms | IDs | Contamination | Raw output |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|---|
| English | official | 67 | 35 | 5.50 | 3895.36 | 80.48 | 3908.55 | 1256.70 | PASS | PASS | [1] Add to cart<br>[2] Buy now<br>[3] Delivery to<br>[4] Contact customer service<br>[5] Network error, please try again |
| English | greedy | 67 | 35 | 5.58 | 3772.75 | 74.04 | 3785.37 | 1248.88 | PASS | PASS | [1] Add to cart<br>[2] Buy now<br>[3] Delivery to<br>[4] Contact customer service<br>[5] Network error, please try again |
| Russian | official | 67 | 62 | 5.16 | 6228.32 | 138.29 | 6239.90 | 2839.41 | PASS | PASS | [1] Добавить в корзину<br>[2] Купить сейчас<br>[3] Доставка в<br>[4] Связаться с службой поддержки<br>[5] Ошибка сети, повторите попытку |
| Russian | greedy | 67 | 67 | 5.29 | 6800.51 | 141.04 | 6812.58 | 2802.83 | PASS | PASS | [1] Добавить в корзину<br>[2] Купить сейчас<br>[3] Доставка в<br>[4] Связаться с обслуживающим персоналом<br>[5] Ошибка сети, повторите попытку |

All four micro-batches preserved IDs 1–5 in order with no semantic contamination, but every micro-batch was slower than five separate warm generations. Micro-batching is not enabled.

## 13. Cold/warm measurements

| Load run | Model load ms | Context ms | Total ms | Status |
|---:|---:|---:|---:|---|
| 1 | 2390.65 | 95.14 | 2486.42 | PASS |
| 2 | 219.51 | 20.56 | 240.08 | PASS |
| 3 | 225.29 | 12.98 | 238.28 | PASS |

- Accepted-run model-load median: 225.29 ms; warm-up translation: 177.07 ms.
- First-ever uncached Metal preflight load+context: 22092.20 ms; review gate exceeded.
- Warm short official median/p95: 285.87 / 1073.67 ms; provisional short-label gate passed before serious thermal state.
- Representative paragraph totals: English official 7556.58 ms, English greedy 7835.21 ms, Russian official 15754.54 ms, Russian greedy 14633.70 ms; p95 15754.54 ms. The long-message gate failed.

Cold translations after load/warm-up:

| Target | Prefill ms | Generation ms | Total ms | Raw output |
|---|---:|---:|---:|---|
| English | 2.47 | 233.83 | 243.43 | Add to cart |
| Russian | 4.94 | 446.11 | 457.77 | Добавить в корзину |

## 14. Memory measurements

- Before load RSS/footprint: 448.89 / 1101.39 MB.
- Ready after warm-up RSS/footprint: 545.41 / 1291.06 MB.
- Sampled peak RSS/footprint: 549.92 / 1291.33 MB.
- Immediately after unload RSS/footprint: 68.92 / 38.84 MB; one second after final unload: 220.09 / 185.53 MB.
- One iOS memory warning; no jetsam or crash. Peak is sampled, not an OS all-time peak.
- The pre-load sample follows full-file SHA verification and is page-cache contaminated; absolute ready/peak physical footprint (~1.29 GB) is the defensible device figure.

## 15. Repeated-run results

- 20/20 native generations completed; no crash, timeout, cancellation leak, or native error.
- Median/p95/max: 909.40 / 6565.95 / 16824.68 ms.
- The repeated phase was at serious thermal state. Cancellation was observed in 1171.51 ms and returned `cancelled=true`.

| Run | Case | Target | Tokens | Generation ms | Total ms | Thermal | Native | Raw output |
|---:|---|---|---:|---:|---:|---|---|---|
| 1 | basic_add_to_cart | English | 3 | 697.89 | 708.98 | serious | PASS | Add to cart |
| 2 | basic_buy_now | Russian | 6 | 898.20 | 909.40 | serious | PASS | Купите сейчас |
| 3 | basic_deliver_to | English | 2 | 553.39 | 564.52 | serious | PASS | Delivery to |
| 4 | basic_contact_service | Russian | 13 | 1490.63 | 1501.83 | serious | PASS | Свяжитесь с службой поддержки |
| 5 | basic_network_error | English | 6 | 857.27 | 868.69 | serious | PASS | Network error, please try again |
| 6 | options_lighting | Russian | 37 | 3732.33 | 3745.39 | serious | PASS | Выбрано: теплый белый свет 3000 К, 54 Вт, размер 260×80 см; 20 штук |
| 7 | options_color | English | 13 | 1791.02 | 1802.42 | serious | PASS | Color classification: Cream white, extra thick (includes installation accessories) |
| 8 | logistics_packaging | Russian | 65 | 6554.06 | 6565.95 | serious | PASS | Для этого груза в дальнейшем будет осуществлен международный транспорт. Пожалуйста, обеспечьте очень надежную упаковку и указывайте название груза на внешней коробке. |
| 9 | seller_fault | English | 22 | 2717.23 | 2728.76 | serious | PASS | Hello, I found that one light does not work after receiving the item. Can you send me additional accessories? |
| 10 | seller_reply | Russian | 50 | 5234.98 | 5246.24 | serious | PASS | Хорошо, пожалуйста, сфотографируйте видео с проблемой. Сегодня мы вышлем вам его вместе с компенсацией. |
| 11 | spec_dimension | English | 4 | 759.55 | 771.26 | serious | PASS | 260×80cm |
| 12 | spec_quantity | Russian | 4 | 730.11 | 741.20 | serious | PASS | 20 штук |
| 13 | spec_currency | English | 2 | 552.15 | 563.46 | serious | PASS | ¥135 |
| 14 | spec_kelvin | Russian | 3 | 638.46 | 649.40 | serious | PASS | 3000К |
| 15 | spec_watts | English | 2 | 552.25 | 563.08 | serious | PASS | 54W |
| 16 | mixed_apple | Russian | 22 | 2539.91 | 2551.23 | serious | PASS | Соответствует Apple MagSafe, модель ST-54W, поддерживает USB-C |
| 17 | mixed_nike | English | 10 | 1479.44 | 1490.47 | serious | PASS | Nike Air Max, Black, Size 42 |
| 18 | representative_paragraph | Russian | 167 | 16812.35 | 16824.68 | serious | PASS | Это набор осветительных изделий, предназначенных для отправки в офшорный склад; всего 20 единиц. Каждый изделие должно быть упаковано в отдельную упаковку и защищено толстым пенопластом от углов. После упаковки необходимо еще раз проверить модель, количество и список аксессуаров, чтобы etikеты на коробке были четкими и водонепроницаемыми, чтобы изделия не повредились в процессе международной доставки из-за сжатия или влаги. |
| 19 | basic_add_to_cart | English | 3 | 686.84 | 697.82 | serious | PASS | Add to cart |
| 20 | basic_buy_now | Russian | 6 | 924.09 | 935.16 | serious | PASS | Купите сейчас |

## 16. Failures/warnings

- Manual quality acceptance failed: 65/72 generation rows passed (90.3%).
- Critical actor reversal in both Russian seller_fault generations.
- Official Russian seller_reply invented compensation.
- Both Russian long-paragraph generations contain target-language/meaning defects.
- Protected-data preservation failed in 6/72 rows due to localized or changed unit strings.
- Representative-paragraph latency was 7.56-15.75 s and exceeded the provisional 3.5 s p95 target.
- The 20-run phase reached serious thermal state; all 20 native calls still completed.
- One iOS memory warning was observed; no crash or jetsam occurred.

Metrics not accurately available: OS all-time peak footprint, jetsam threshold/headroom, and true first-token backend timing separate from vocabulary sampling. They are not fabricated.

## 17. Q4 decision

**NO-GO QUALITY.** Q4 fails hard quality gates: reviewed acceptance is 65/72 generation rows (90.3%); both sampling strategies are below 95% in English and Russian; one Russian seller-chat source has a critical actor reversal in both strategies; official sampling invents compensation; and protected spans fail in 6/72 rows because Russian output changes exact K/W/cm forms. Performance also misses the long-message gate, but memory and native stability do not drive this classification.

Memory was within the provisional envelope and 20/20 repeated calls were native-stable. Performance also failed the long-message gate and degraded under serious thermal load, but quality alone is a hard stop.

## 18. Recommended exact Stage 2 configuration if GO

Not applicable: Q4 is not a GO, no production sampling configuration is frozen, and Stage 2 was not started.

## 19. Recommended next experiment if NO-GO

Run the audit-recommended Hy-MT2-1.8B Q8_0 Mac reference with the same embedded Jinja template, both mandated sampling strategies, and this exact EN/RU dataset—starting with `seller_fault`, `seller_reply`, the protected-unit cases, and the long paragraph. If Q8 repeats the actor reversal, hallucination, unit changes, and Russian paragraph defects, reject the Hy-MT2 base model for this product. If Q8 passes, isolate Q4 quantization loss before considering another iPhone-supported quantization. Do **not** test STQ yet: Q4 did not fail primarily on memory/stability, and STQ was not implemented.

## 20. Production screenshot behavior

Production screenshot behavior changed: **false**. The Debug-only harness does not invoke or alter foreground screenshot translation, App Intent screenshot flows, grouping, overlays, Apple Translation, remote FastAPI, dictionary, or CEDICT production/development routing. No Stage 2 work was performed.
