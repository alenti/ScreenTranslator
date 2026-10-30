# Stage 1A — Hy-MT2 quality isolation

Generated 2026-08-20T07:34:39.902Z. This is a Mac/reference quality experiment only, not an iPhone performance result.

## Decision

- Q4: already **NO-GO QUALITY**.
- Q8: **Q8 QUALITY FAIL** — 66/72 manual passes (91.67%); English 36/36, Russian 30/36. Important Russian seller-chat failures remain, including incorrect seller action and invented documentation/file; Q8 also converts 54W to 54В (volts) once.
- BF16: **BF16 QUALITY FAIL** — 4/7 critical-subset passes. It fixes Q8's Russian seller-fault actor/action error and wattage, but retains ambiguous reshipment objects and emits English residue/malformed Russian in the long paragraph.
- Q6: **NOT TESTED** because Q8 did not pass its quality gate.

Conclusion: **Hy-MT2-1.8B base model is unsuitable for the required quality bar.** Q8 and BF16 differ, so this does not establish that quantization has no effect; it establishes that BF16 does not restore the required quality gate. Do not begin Stage 2 or implement STQ.

## Scope and Git safety

- No production screenshot, OCR, grouping, rendering, App Intent, Apple Translation, remote translation, or CEDICT behavior was changed.
- No commit, push, branch, reset, clean, stash, checkout, or overwrite operation was performed.
- Stage 1A additions: tools/on_device_llama/stage1a_hymt2_quality.py, tools/on_device_llama/stage1a_hymt2_bf16.py, docs/STAGE_1A_HYMT2_QUALITY_ISOLATION.md, docs/benchmarks/<this report>.json.
- Initial branch/HEAD: main / 19d01e24aadd45847b277c2626308927a4cc3638. The substantial pre-existing dirty worktree was preserved; its Stage 1A end state is represented in the JSON artifact.

## Reproducible inputs and execution control

- Q4 source: Tencent [Hy-MT2-1.8B-Q4_K_M.gguf](https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF) at revision 1cd5208700acedef4ef93019b6cfc148b8522d45; 1133080448 bytes, SHA-256 dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699.
- Q8: Tencent [Hy-MT2-1.8B-Q8_0.gguf](https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF) at revision 1cd5208700acedef4ef93019b6cfc148b8522d45; 1908528192 bytes, SHA-256 5c3fe0b1408a5ceb0143184ef247b11b579c525f4b02b060e6c851bb76fef1a4 (verified).
- llama.cpp source pin: b062ba735e5e15817f6a1dbdb84717ee3097f619; Release host reference build, Metal enabled, native CPU optimization enabled. The comparison uses llama-completion --jinja, which selects the embedded GGUF Jinja template.
- Source archive SHA-256: 67fd3fee8559c3db276219f0ca22fe8b985c965c690d90c718d33f8ff44034d4. The CLI's displayed build commit 74845fc is a CMake archive-source discovery artifact from an enclosing unrelated Git repository, not the llama.cpp revision; the source archive is the evidence for the b062 pin.
- Shared template SHA-256: b7491ec0e9c869dfce20f2176758099bf248d979dd05530ede99deb21698acee; Q8 template equals Q4's Stage 1 template.
- Instruction: Translate the following text into {English|Russian}. Note that you should only output the translated result without any additional explanation: {source}. No system prompt or cleanup/correction was added.
- Shared test runtime: ctx 2048, batch 256, ubatch 128, threads 4, all layers requested for Metal. Raw output strips only llama-completion's EOG presentation sentinel; original CLI stdout bytes are retained Base64 in the JSON.

## Official sampling discrepancy

The official GGUF README at revision 1cd5208700acedef4ef93019b6cfc148b8522d45 documents temperature 0.7, top-p 0.6, top-k 20, repetition penalty 1.05. The official base [generation_config.json](https://huggingface.co/tencent/Hy-MT2-1.8B/blob/9a341cd1b679d3efd23b46e847b01745a71ed792/generation_config.json) at BF16 revision 9a341cd1b679d3efd23b46e847b01745a71ed792 says top-p 0.8 with the other values unchanged. The file history shows 0.8 from initial weights revision 1fa8bee through the pinned BF16 revision, while the GGUF README remains 0.6.

Full Q8 and the BF16 subset therefore hold the Stage 1/official-GGUF README setting at top-p 0.6. The only added sampling control is top-p 0.8 on four Q4 semantic-failure official-sampling rows. It still asks whether the customer may deliver spare parts and still changes the Russian reshipment to duplicate documentation; it does not resolve the seller failures.

| case | target | Q8 top-p 0.8 raw output |
| --- | --- | --- |
| seller_fault | Russian | Здравствуйте, я получил товар, но обнаружил, что один из светильников не работает. Можно ли мне доставить запасные части? |
| seller_reply | English | Yes, please take a video of the problem. We will send you a replacement today. |
| seller_reply | Russian | Конечно, пожалуйста, сфотографируйте видео с момента возникновения неисправности. Сегодня мы вышлем вам дубликат документации. |
| representative_paragraph | Russian | Это партия осветительных приборов, предназначенных для отправки в зарубежный склад. Всего 20 единиц товара. Каждый из этих приборов необходимо упаковать в отдельные пакеты, а углы пакета защитить усиленным поролоном. После упаковки просим ещё раз проверить модели, количество товаров и список аксессуаров. Необходимо также убедиться, что этикетка на коробке четкая и водонепроницаемая, чтобы предотвратить повреждения при международной доставке из-за сжатия или влажности. |

## Q8 quality result

- Manual quality: 66/72 (91.67%); English 36/36; Russian 30/36.
- Semantic value preservation: 71/72. One real semantic unit failure: Russian official 54W → 54В (volts).
- Exact source-form preservation: 63/72. The other exact-form differences are benign localized K/cm/Вт or spacing where numeric semantic value remains intact.
- Q8 run: 2026-08-20T07:23:41.920580+00:00–2026-08-20T07:24:39.604778+00:00; every row exited 0 and reached EOG. Host latency is retained for sanity in JSON only and is not used to select an iPhone candidate.

### Primary discriminators

- **seller_fault:** Q8 Russian no longer uses Q4's 'we' actor, but it asks whether the customer can replace a faulty set instead of asking the seller to resend a part. Both official and greedy fail.
- **seller_reply:** Q8 English explicitly says 'replacement' and passes. Russian official invents duplicate documentation; Russian greedy says it will send a file. Both fail.
- **representative paragraph:** Q8 Russian removes Q4's offshore/mixed-script label degradation and is accepted for both samplers.

### Full Q4 vs Q8 raw-output matrix

| case | target | sampling | source | Q4 raw | Q8 raw | Q8 manual review | difference from Q4 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| basic_add_to_cart | English | official | 加入购物车 | Add to cart | Add to cart | PASS | No material quality difference found. |
| basic_add_to_cart | English | greedy | 加入购物车 | Add to cart | Add to cart | PASS | No material quality difference found. |
| basic_add_to_cart | Russian | official | 加入购物车 | Добавить в корзину | Добавить в корзину | PASS | No material quality difference found. |
| basic_add_to_cart | Russian | greedy | 加入购物车 | Добавить в корзину | Добавить в корзину | PASS | No material quality difference found. |
| basic_buy_now | English | official | 立即购买 | Buy now | Buy now | PASS | No material quality difference found. |
| basic_buy_now | English | greedy | 立即购买 | Buy now | Buy now | PASS | No material quality difference found. |
| basic_buy_now | Russian | official | 立即购买 | Купите сейчас | Приобрести сейчас | PASS | No material quality difference found. |
| basic_buy_now | Russian | greedy | 立即购买 | Купить сейчас | Покупайте сейчас. | PASS | No material quality difference found. |
| basic_deliver_to | English | official | 配送至 | Delivery to | Delivery to | PASS | No material quality difference found. |
| basic_deliver_to | English | greedy | 配送至 | Delivery to | Delivery to | PASS | No material quality difference found. |
| basic_deliver_to | Russian | official | 配送至 | Доставка до | Доставка в | PASS | No material quality difference found. |
| basic_deliver_to | Russian | greedy | 配送至 | Доставка до | Доставка в | PASS | No material quality difference found. |
| basic_contact_service | English | official | 联系客服 | Contact customer service | Contact customer service | PASS | No material quality difference found. |
| basic_contact_service | English | greedy | 联系客服 | Contact customer service | Contact customer service | PASS | No material quality difference found. |
| basic_contact_service | Russian | official | 联系客服 | Свяжитесь с службой поддержки | Свяжитесь с службой поддержки клиентов. | PASS | No material quality difference found. |
| basic_contact_service | Russian | greedy | 联系客服 | Свяжитесь с службой поддержки | Свяжитесь с обслуживающим персоналом. | PASS | No material quality difference found. |
| basic_network_error | English | official | 网络错误，请重试 | Network error, please try again | Network error, please try again. | PASS | No material quality difference found. |
| basic_network_error | English | greedy | 网络错误，请重试 | Network error, please try again | Network error, please try again. | PASS | No material quality difference found. |
| basic_network_error | Russian | official | 网络错误，请重试 | Ошибка сети, пожалуйста, попробуйте снова | Произошла сетевая ошибка, пожалуйста, попробуйте снова. | PASS | No material quality difference found. |
| basic_network_error | Russian | greedy | 网络错误，请重试 | Ошибка сети, пожалуйста, попробуйте снова | Произошла сетевая ошибка. Пожалуйста, попробуйте снова. | PASS | No material quality difference found. |
| options_lighting | English | official | 已选：暖白光 3000K，54W，260×80cm；20件 | Selected: Warm white light 3000K, 54W, 260×80cm; 20 pieces | Selected: Warm white light, 3000K, 54W, 260×80cm; 20 pieces | PASS | No material quality difference found. |
| options_lighting | English | greedy | 已选：暖白光 3000K，54W，260×80cm；20件 | Selected: Warm white light 3000K, 54W, 260×80cm; 20 pieces | Selected: Warm white light, 3000K, 54W, 260×80cm; 20 pieces | PASS | No material quality difference found. |
| options_lighting | Russian | official | 已选：暖白光 3000K，54W，260×80cm；20件 | Выбрано: теплый белый свет 3000 К, 54 Вт, размер 260×80 см; 20 штук | Выбранный вариант: теплый белый свет, 3000 К, 54 Вт, размеры 260×80 см; 20 штук. | PASS | No material quality difference found. |
| options_lighting | Russian | greedy | 已选：暖白光 3000K，54W，260×80cm；20件 | Выбран: теплый белый свет 3000 К, 54 Вт, размер 260×80 см; 20 штук | Выбранный вариант: теплый белый свет, 3000 К, 54 Вт, размеры 260×80 см; 20 штук. | PASS | No material quality difference found. |
| options_color | English | official | 颜色分类：奶油白 加厚款（含安装配件） | Color classification: Cream white, extra thick (includes installation accessories) | Color category: Cream White, Thick version (including installation accessories) | PASS | No material quality difference found. |
| options_color | English | greedy | 颜色分类：奶油白 加厚款（含安装配件） | Color category: Cream white, extra thick (includes installation accessories) | Color category: Cream White, Thickened version (including installation accessories) | PASS | No material quality difference found. |
| options_color | Russian | official | 颜色分类：奶油白 加厚款（含安装配件） | Классификация цвета: кремово-белый, толстый вариант (включая комплект для установки) | Цвет: кремовый белый. Толстая версия (включает инсталляционные компоненты). | PASS | No material quality difference found. |
| options_color | Russian | greedy | 颜色分类：奶油白 加厚款（含安装配件） | Классификация цвета: кремово-белый, толстый вариант (включая комплект для установки) | Цвет: кремовый белый. Упрофильная версия (содержит все необходимые компоненты для установки). | FAIL_MEANING | REGRESSION: Q4 was accepted; Q8 changes thickened to profiled. |
| logistics_packaging | English | official | 这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。 | This shipment will also be transported internationally later. Please ensure it is well-secured in packaging, and indicate the name of the goods on the outer box. | This shipment will also be transported internationally later on. Please make sure to package it very securely, and indicate the name of the goods on the outer packaging. | PASS | No material quality difference found. |
| logistics_packaging | English | greedy | 这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。 | This shipment will also be transported internationally later. Please ensure it is well-packed and indicate the item name on the outer box. | This shipment will also be transported internationally later on. Please make sure to pack it in a very sturdy manner, and indicate the name of the goods on the outer packaging. | PASS | No material quality difference found. |
| logistics_packaging | Russian | official | 这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。 | Для этого груза в дальнейшем будет осуществлен международный транспорт. Пожалуйста, обеспечьте очень надежную упаковку и указывайте название груза на внешней коробке. | Эту партию товаров ещё предстоит доставить по международным маршрутам. Поэтому необходимо тщательно упаковать товары, а на внешней упаковке должно быть указано название товара. | PASS | No material quality difference found. |
| logistics_packaging | Russian | greedy | 这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。 | Для этой партики товара будет дальнейший международный транспорт. Пожалуйста, обеспечьте очень надежную упаковку, и указывайте название товара на внешней коробке. | Этот груз будет доставлен по международным маршрутам. Поэтому необходимо тщательно упаковать товары, а на внешней упаковке должно быть указано название груза. | PASS | No material quality difference found. |
| seller_fault | English | official | 您好，我收到货后发现有一个灯不亮，可以补发配件吗？ | Hello, I found that one light does not work after receiving the item. Can you send me additional accessories? | Hello, I noticed that one of the lights doesn’t work after receiving the product. Can I get a replacement for it? | PASS | No material quality difference found. |
| seller_fault | English | greedy | 您好，我收到货后发现有一个灯不亮，可以补发配件吗？ | Hello, I found that one light does not work after receiving the item. Can you send me the missing parts? | Hello, I noticed that one of the lights doesn’t work after I received the product. Can I get a replacement for it? | PASS | No material quality difference found. |
| seller_fault | Russian | official | 您好，我收到货后发现有一个灯不亮，可以补发配件吗？ | Здравствуйте, я получил товар, но обнаружил, что одна лампа не работает. Можем ли мы отправить дополнительные компоненты? | Здравствуйте, я получил товар, но обнаружил, что одна лампа не работает. Можно ли мне заменить неисправный комплект? | FAIL_SELLER_ACTION | IMPROVEMENT BUT FAIL: Q4 reversed the actor; Q8 keeps the customer as speaker but changes the requested seller action. |
| seller_fault | Russian | greedy | 您好，我收到货后发现有一个灯不亮，可以补发配件吗？ | Здравствуйте, я получил товар, но обнаружил, что одна лампа не работает. Можем ли мы отправить дополнительные комплектующие? | Здравствуйте, после получения товара я обнаружил, что одна лампочка не работает. Можно ли мне заменить неисправный комплект? | FAIL_SELLER_ACTION | IMPROVEMENT BUT FAIL: Q4 reversed the actor; Q8 keeps the customer as speaker but changes the requested seller action. |
| seller_reply | English | official | 可以的，麻烦拍一下故障视频，我们今天给您补发。 | Yes, please take a video of the malfunction. We will send it to you again today. | Yes, please take a video of the problem. We will send you a replacement today. | PASS | FIX: Q4's ambiguous resend object became an explicit replacement. |
| seller_reply | English | greedy | 可以的，麻烦拍一下故障视频，我们今天给您补发。 | Yes, please take a video of the malfunction. We will send it to you again today. | Yes, please take a video of the issue. We will send you a replacement today. | PASS | FIX: Q4's ambiguous resend object became an explicit replacement. |
| seller_reply | Russian | official | 可以的，麻烦拍一下故障视频，我们今天给您补发。 | Хорошо, пожалуйста, сфотографируйте видео с проблемой. Сегодня мы вышлем вам его вместе с компенсацией. | Конечно, пожалуйста, сфотографируйте видео с момента возникновения неисправности. Сегодня мы вышлем вам дубликат документации. | FAIL_HALLUCINATION | FAILURE CHANGED: Q4 invented compensation; Q8 instead invents duplicate documentation. |
| seller_reply | Russian | greedy | 可以的，麻烦拍一下故障视频，我们今天给您补发。 | Хорошо, пожалуйста, сфотографируйте видео с проблемой. Сегодня мы вышлем вам дополнительный экземпляр. | Конечно, пожалуйста, сфотографируйте видео с моментом возникновения неисправности. Сегодня мы вышлем вам этот файл. | FAIL_HALLUCINATION | REGRESSION: Q4 was accepted; Q8 says it will send a file. |
| spec_dimension | English | official | 260×80cm | 260×80cm | 260×80 cm | PASS | No material quality difference found. |
| spec_dimension | English | greedy | 260×80cm | 260×80cm | 260×80 cm | PASS | No material quality difference found. |
| spec_dimension | Russian | official | 260×80cm | 260×80 см | 260×80 см | PASS | No material quality difference found. |
| spec_dimension | Russian | greedy | 260×80cm | 260×80 см | 260×80 см | PASS | No material quality difference found. |
| spec_quantity | English | official | 20件 | 20 pieces | 20 items | PASS | No material quality difference found. |
| spec_quantity | English | greedy | 20件 | 20 pieces | 20 items | PASS | No material quality difference found. |
| spec_quantity | Russian | official | 20件 | 20 штук | 20 штук | PASS | No material quality difference found. |
| spec_quantity | Russian | greedy | 20件 | 20 штук | 20 штук | PASS | No material quality difference found. |
| spec_currency | English | official | ¥135 | ¥135 | ¥135 | PASS | No material quality difference found. |
| spec_currency | English | greedy | ¥135 | ¥135 | ¥135 | PASS | No material quality difference found. |
| spec_currency | Russian | official | ¥135 | ¥135 | ¥135 | PASS | No material quality difference found. |
| spec_currency | Russian | greedy | ¥135 | ¥135 | ¥135 | PASS | No material quality difference found. |
| spec_kelvin | English | official | 3000K | 3000K | 3000K | PASS | No material quality difference found. |
| spec_kelvin | English | greedy | 3000K | 3000K | 3000K | PASS | No material quality difference found. |
| spec_kelvin | Russian | official | 3000K | 3000К | 3000К | PASS | No material quality difference found. |
| spec_kelvin | Russian | greedy | 3000K | 3000К | 3000К | PASS | No material quality difference found. |
| spec_watts | English | official | 54W | 54W | 54W | PASS | No material quality difference found. |
| spec_watts | English | greedy | 54W | 54W | 54W | PASS | No material quality difference found. |
| spec_watts | Russian | official | 54W | 54W | 54В | FAIL_PROTECTED_SEMANTIC | REGRESSION: Q4 retained watts; Q8 produces volts. |
| spec_watts | Russian | greedy | 54W | 54W | 54W | PASS | No material quality difference found. |
| mixed_apple | English | official | Apple MagSafe 兼容，型号 ST-54W，支持 USB-C | Compatible with Apple MagSafe, model ST-54W, supports USB-C | Compatible with Apple MagSafe, model ST-54W. Supports USB-C. | PASS | No material quality difference found. |
| mixed_apple | English | greedy | Apple MagSafe 兼容，型号 ST-54W，支持 USB-C | Compatible with Apple MagSafe, model ST-54W, supports USB-C | Compatible with Apple MagSafe, model ST-54W, supports USB-C | PASS | No material quality difference found. |
| mixed_apple | Russian | official | Apple MagSafe 兼容，型号 ST-54W，支持 USB-C | Соответствует Apple MagSafe, модель ST-54W, поддерживает USB-C | Соответствует стандартам Apple MagSafe; модель ST-54W. Поддерживается интерфейс USB-C. | PASS | No material quality difference found. |
| mixed_apple | Russian | greedy | Apple MagSafe 兼容，型号 ST-54W，支持 USB-C | Совместим с Apple MagSafe, модель ST-54W, поддержка USB-C | Соответствует стандартам Apple MagSafe; модель ST-54W. Поддерживается технология USB-C. | PASS | No material quality difference found. |
| mixed_nike | English | official | Nike Air Max 黑色 42码 | Nike Air Max, Black, Size 42 | Nike Air Max Black, Size 42 | PASS | No material quality difference found. |
| mixed_nike | English | greedy | Nike Air Max 黑色 42码 | Nike Air Max Black, Size 42 | Nike Air Max Black, Size 42 | PASS | No material quality difference found. |
| mixed_nike | Russian | official | Nike Air Max 黑色 42码 | Nike Air Max, черный цвет, размер 42 | Nike Air Max, черный цвет, размер 42 | PASS | No material quality difference found. |
| mixed_nike | Russian | greedy | Nike Air Max 黑色 42码 | Nike Air Max, черный, размер 42 | Nike Air Max, черный цвет, размер 42 | PASS | No material quality difference found. |
| representative_paragraph | English | official | 这是一批准备发往海外仓的照明产品，共有20件。每件产品都需要单独套袋，并用加厚泡沫保护四角。装箱后请再次核对型号、数量和配件清单，确保外箱标签清晰、防水，避免在国际运输途中因挤压或受潮造成损坏。 | This is a batch of lighting products ready to be shipped to the overseas warehouse, consisting of 20 items in total. Each product needs to be placed in a separate bag and protected with thick foam at the corners. After packing, please check again the model numbers, quantities, and accessory lists to ensure that the outer box labels are clear and waterproof, so as to prevent damage due to compression or moisture during international transportation. | This is a batch of lighting products that are to be sent to the overseas warehouse. There are 20 units in total. Each product needs to be packaged separately, with its four corners protected by thickened foam. After packing, please check the model number, quantity, and list of accessories again to ensure that the outer packaging labels are clear and waterproof. This will help prevent damage due to pressure or moisture during international transportation. | PASS | No material quality difference found. |
| representative_paragraph | English | greedy | 这是一批准备发往海外仓的照明产品，共有20件。每件产品都需要单独套袋，并用加厚泡沫保护四角。装箱后请再次核对型号、数量和配件清单，确保外箱标签清晰、防水，避免在国际运输途中因挤压或受潮造成损坏。 | This is a batch of lighting products ready to be shipped to the overseas warehouse, consisting of 20 items. Each product needs to be packed in a separate bag, and the four corners should be protected with thick foam. After packing, please check again the model numbers, quantities, and accessory lists to ensure that the outer boxes have clear labels and are waterproof, so as to prevent damage due to pressure or moisture during international transportation. | This is a batch of lighting products that are to be shipped to the overseas warehouse. There are 20 items in total. Each product needs to be individually wrapped in bags, with the corners protected by thickened foam. After packing, please check the model, quantity, and list of accessories again to ensure that the outer packaging labels are clear and waterproof. This will help prevent damage due to compression or moisture during international transportation. | PASS | No material quality difference found. |
| representative_paragraph | Russian | official | 这是一批准备发往海外仓的照明产品，共有20件。每件产品都需要单独套袋，并用加厚泡沫保护四角。装箱后请再次核对型号、数量和配件清单，确保外箱标签清晰、防水，避免在国际运输途中因挤压或受潮造成损坏。 | Это набор осветительных изделий, предназначенных для отправки в офшорный склад; всего 20 единиц. Каждый изделие должно быть упаковано в отдельную упаковку и защищено толстым пенопластом от углов. После упаковки необходимо еще раз проверить модель, количество и список аксессуаров, чтобы etikеты на коробке были четкими и водонепроницаемыми, чтобы изделия не повредились в процессе международной доставки из-за сжатия или влаги. | Это партия осветительных приборов, предназначенных для отправки в зарубежный склад. Всего 20 единиц товара. Каждый из этих приборов необходимо упаковать в отдельные пакеты, а углы пакета защитить усиленным пеном. После упаковки важно еще раз проверить модель, количество и список комплектующих. Необходимо также убедиться, что этикетка на коробке четко видима и имеет водонепроницаемый покрой, чтобы предотвратить повреждения при международной доставке из-за сжатия или влаги. | PASS | FIX: Q4's offshore/mixed-script label degradation is absent; meaning is accepted. |
| representative_paragraph | Russian | greedy | 这是一批准备发往海外仓的照明产品，共有20件。每件产品都需要单独套袋，并用加厚泡沫保护四角。装箱后请再次核对型号、数量和配件清单，确保外箱标签清晰、防水，避免在国际运输途中因挤压或受潮造成损坏。 | Это партия осветительных изделий, предназначенных для отправки в зарубежный склад, всего 20 единиц. Каждое изделие необходимо упаковать в отдельный пакет и защитить углы толстым пенопластом. После упаковки повторно проверьте модель, количество и список аксессуаров, чтобы обеспечить четкую и водонепроницаемую etику внешнего пакета, чтобы изделия не повредились из-за давления или влаги во время международной доставки. | Это партия осветительных приборов, предназначенных для отправки в зарубежный склад. Всего 20 единиц товара. Каждый из этих приборов необходимо упаковать в отдельные пакеты, а углы пакета защитить толстым пеном. После упаковки необходимо ещё раз проверить модель, количество и список аксессуаров. Убедитесь, что этикетки на коробке четкие и водонепроницаемые, чтобы предотвратить повреждения при международной доставке из-за сжатия или влажности. | PASS | FIX: Q4's offshore/mixed-script label degradation is absent; meaning is accepted. |

## BF16 diagnostic subset

- Official base repository: [tencent/Hy-MT2-1.8B](https://huggingface.co/tencent/Hy-MT2-1.8B), revision 9a341cd1b679d3efd23b46e847b01745a71ed792.
- Weights: model.safetensors, 4077072784 bytes, SHA-256 29e9117a44c79f81857613601968ff482d8a23c2d6736a1710bba9e5ca4762e5.
- Template: chat_template.jinja, SHA-256 b7491ec0e9c869dfce20f2176758099bf248d979dd05530ede99deb21698acee, equal to the Q8 GGUF template.
- Runtime: Transformers 5.15.1; PyTorch 2.13.0; torch.bfloat16; mps; MPS available: true. Official AutoTokenizer.apply_chat_template and AutoModelForCausalLM.generate were used.
- Sampling control: fixed seed 20260820, temperature 0.7, top-p 0.6, top-k 20, repetition penalty 1.05. All seven rows ended with configured EOS. A Transformers BPE cleanup warning was logged; it states cleanup is ignored, and no cleanup was applied.

| case | target | Q4 raw | Q8 raw | BF16 raw | BF16 manual review | rationale |
| --- | --- | --- | --- | --- | --- | --- |
| seller_fault | English | Hello, I found that one light does not work after receiving the item. Can you send me additional accessories? | Hello, I noticed that one of the lights doesn’t work after receiving the product. Can I get a replacement for it? | Hello, I found that one light does not work after receiving the item. Can you send me the missing parts? | PASS | Customer request for replacement parts is preserved. |
| seller_fault | Russian | Здравствуйте, я получил товар, но обнаружил, что одна лампа не работает. Можем ли мы отправить дополнительные компоненты? | Здравствуйте, я получил товар, но обнаружил, что одна лампа не работает. Можно ли мне заменить неисправный комплект? | Здравствуйте, я обнаружил, что после получения товара одна лампа не работает. Можете отправить дополнительные комплектующие? | PASS | Customer asks seller to send additional components; Q8 actor failure is fixed. |
| seller_reply | English | Yes, please take a video of the malfunction. We will send it to you again today. | Yes, please take a video of the problem. We will send you a replacement today. | Sure, please take a video of the malfunction. We will send it to you again today. | FAIL_MEANING | The object to be resent remains the ambiguous pronoun 'it', matching the Stage 1 concern. |
| seller_reply | Russian | Хорошо, пожалуйста, сфотографируйте видео с проблемой. Сегодня мы вышлем вам его вместе с компенсацией. | Конечно, пожалуйста, сфотографируйте видео с момента возникновения неисправности. Сегодня мы вышлем вам дубликат документации. | Да, пожалуйста, сфотографируйте видео с ошибкой. Сегодня мы вышлем вам его дополнительно. | FAIL_MEANING | The object to be resent remains an ambiguous pronoun ('его'). |
| representative_paragraph | English | This is a batch of lighting products ready to be shipped to the overseas warehouse, consisting of 20 items in total. Each product needs to be placed in a separate bag and protected with thick foam at the corners. After packing, please check again the model numbers, quantities, and accessory lists to ensure that the outer box labels are clear and waterproof, so as to prevent damage due to compression or moisture during international transportation. | This is a batch of lighting products that are to be sent to the overseas warehouse. There are 20 units in total. Each product needs to be packaged separately, with its four corners protected by thickened foam. After packing, please check the model number, quantity, and list of accessories again to ensure that the outer packaging labels are clear and waterproof. This will help prevent damage due to pressure or moisture during international transportation. | These are a batch of lighting products ready to be shipped to the overseas warehouse, totaling 20 pieces. Each product needs to be packaged separately and protected with thick foam at the four corners. After packing, please check again the model numbers, quantities, and accessory lists to ensure the outer box labels are clear and waterproof, so as to prevent damage due to pressure or moisture during international transportation. | PASS | Essential packaging, quantity, label, and international-shipping meaning are preserved. |
| representative_paragraph | Russian | Это набор осветительных изделий, предназначенных для отправки в офшорный склад; всего 20 единиц. Каждый изделие должно быть упаковано в отдельную упаковку и защищено толстым пенопластом от углов. После упаковки необходимо еще раз проверить модель, количество и список аксессуаров, чтобы etikеты на коробке были четкими и водонепроницаемыми, чтобы изделия не повредились в процессе международной доставки из-за сжатия или влаги. | Это партия осветительных приборов, предназначенных для отправки в зарубежный склад. Всего 20 единиц товара. Каждый из этих приборов необходимо упаковать в отдельные пакеты, а углы пакета защитить усиленным пеном. После упаковки важно еще раз проверить модель, количество и список комплектующих. Необходимо также убедиться, что этикетка на коробке четко видима и имеет водонепроницаемый покрой, чтобы предотвратить повреждения при международной доставке из-за сжатия или влаги. | Это набор осветительных изделий, предназначенных для отправки в зарубежный склад; всего 20 единиц. Каждое изделие необходимо упаковать в отдельную упаковку и защитить углы толстым пенопластом. После упаковки повторно проверьте модели, количество и список аксессуаров, чтобы обратить внимание diagonally яркие и водонепроницаемые этикетки, чтобы избежать повреждений в процессе международной доставки из-за сжатия или испарения влаги. | FAIL_LANGUAGE_AND_MEANING | Contains English residue ('diagonally'), malformed label wording, and changes moisture damage to evaporation of moisture. |
| spec_watts | Russian | 54W | 54В | 54W | PASS | 54W is retained. |

BF16 passes 4/7 critical rows (57.14%) and fails material seller-reply meaning and the Russian representative paragraph. This is Case C of the diagnosis matrix: Q8 and BF16 both fail material semantic quality, so Q6 is not justified and model selection should be reopened.

## Next experiment

Screen an independent Chinese-to-English/Russian candidate at BF16/FP16 first, using this exact seller-chat plus representative-paragraph subset and raw-output review. Only a candidate that clears this quality gate should proceed to a separate iPhone runtime experiment.

Machine-readable evidence: [stage1a_hymt2_quality_isolation_20260820T073439902Z.json](benchmarks/stage1a_hymt2_quality_isolation_20260820T073439902Z.json).
