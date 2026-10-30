# Stage 1B — Hy-MT2 rescue without training

Generated 2026-08-20T08:34:45.074Z. This is a BF16 Mac/reference quality experiment; its latency is sanity data, not an iPhone prediction.

## Verdict

**HY-MT2 NEEDS SPECIALIZATION.** The rescue controls improve real failures, but no BF16 strategy clears the seller-chat and Russian-quality gates. Q4 was therefore not retested.

- Best instruction: Tencent's Chinese-native default prompt.
- Best context strategy: none is safe for production. The source-first form was least bad, but no tested context form achieved zero context/prompt leakage.
- Best long-text strategy: Chinese-native whole paragraph; segmentation is not selected.
- Terminology: useful only as narrow, exact terminology guidance; insufficient as a quality rescue.
- Protected spans: exact data preservation works, but it is not a semantic-quality fix and costs latency/naturalness.
- BF16: FAIL — combined greedy candidate 14/20 (70%); English 9/10, Russian 5/10. Official sampler: 13/20; it does not materially improve the failures.
- Q4: NOT RETESTED — BF16 did not pass the gates.

## Scope, baseline, and Git state

- Stage 1A baseline raw outputs were read unchanged and remain intact.
- No Stage 2, STQ, fine-tuning, production screenshot translation change, production-path deletion, commit, push, reset, clean, stash, or checkout was performed.
- Branch/HEAD remain main / 19d01e24aadd45847b277c2626308927a4cc3638; the pre-existing dirty worktree was preserved.
- The original 17 modified tracked files remain the tracked diff; all untracked project entries are preserved. Exact final status, diff stat, and tracked names are in the JSON.
- Stage 1B repository additions: tools/on_device_llama/stage1b_hymt2_rescue.py; docs/STAGE_1B_HYMT2_RESCUE.md; docs/benchmarks/stage1b_hymt2_rescue_20260820T083445074Z.json. External raw evidence remains under BuildArtifacts/stage1b and is hash-recorded in the JSON.

## BF16 model and official controls

- Official model: [tencent/Hy-MT2-1.8B](https://huggingface.co/tencent/Hy-MT2-1.8B), revision 9a341cd1b679d3efd23b46e847b01745a71ed792; model.safetensors 4077072784 bytes, SHA-256 29e9117a44c79f81857613601968ff482d8a23c2d6736a1710bba9e5ca4762e5.
- Runtime: Transformers 5.15.1; PyTorch 2.13.0; torch.bfloat16; mps; MPS available true; official AutoTokenizer.apply_chat_template and AutoModelForCausalLM.generate.
- Template SHA-256: b7491ec0e9c869dfce20f2176758099bf248d979dd05530ede99deb21698acee; no system prompt, cleanup, dictionary, fallback translator, semantic repair, or manual output replacement.
- Tencent documents the Chinese default, terminology, and background-information forms used here. Its model-card inference parameters are temperature 0.7, top-p 0.6, top-k 20, repetition penalty 1.05, seed 20260820. The pinned base generation_config.json still has top-p 0.8; 0.6 is retained for Stage 1 comparability and separately compared against greedy.

## Instruction A/B — 0-context chat holdout

The reproducible holdout has 10 Chinese commerce/seller cases (the original seller pair plus nine additions) and covers omitted subject/object, pronouns, replacement, returns, shipping, parts, faults, packaging, quantity, logistics, USB-C, and ST-54W. Each current message is translated alone to EN/RU. The complete 80-row raw matrix is in JSON.

The Chinese prompt changes the original English seller reply from ambiguous 'send it' to 'send you a replacement'. It does not make the Russian reply's object explicit without terminology/context.

| case | target | instruction | sampling | raw output |
| --- | --- | --- | --- | --- |
| seller_reply_original | English | english | official | Sure, please take a video of the malfunction. We will send it to you again today. |
| seller_reply_original | English | english | greedy | Sure, please take a video of the malfunction. We will send it to you again today. |
| seller_reply_original | English | chinese | official | Sure, please take a video of the malfunction. We will send you a replacement today. |
| seller_reply_original | English | chinese | greedy | Yes, please take a video of the malfunction. We will send you a replacement today. |
| seller_reply_original | Russian | english | official | Да, пожалуйста, сфотографируйте видео с ошибкой. Сегодня мы вышлем вам его дополнительно. |
| seller_reply_original | Russian | english | greedy | Да, пожалуйста, сфотографируйте видео с проблемой. Сегодня мы вышлем вам его дополнительно. |
| seller_reply_original | Russian | chinese | official | Можно. Пожалуйста, снимите видео с проблемой, и мы вышлем вам его сегодня. |
| seller_reply_original | Russian | chinese | greedy | Можно. Пожалуйста, снимите видео с ошибкой, и мы отправим вам его сегодня. |
| replacement_object_two_turns | English | english | official | Sure, I’ll send it to you again today. |
| replacement_object_two_turns | English | english | greedy | Yes, I’ll send it to you again today. |
| replacement_object_two_turns | English | chinese | official | Yes, we will send it to you again today. |
| replacement_object_two_turns | English | chinese | greedy | Yes, we will send it to you again today. |
| replacement_object_two_turns | Russian | english | official | Можно, сегодня вышлем вам дополнительную копию. |
| replacement_object_two_turns | Russian | english | greedy | Можно, сегодня отправим вам дополнительную партию. |
| replacement_object_two_turns | Russian | chinese | official | Можно, сегодня отправим вам дополнительную партию. |
| replacement_object_two_turns | Russian | chinese | greedy | Можно, сегодня отправим вам дополнительный экземпляр. |
| usb_c_fault_two_turns | English | english | official | If there is an interface failure after receiving it, can accessories be sent again? |
| usb_c_fault_two_turns | English | english | greedy | If there is an interface failure after receiving it, can I get replacement parts sent? |
| usb_c_fault_two_turns | English | chinese | official | If there is a failure with the receiving interface after receipt, can we send replacement parts? |
| usb_c_fault_two_turns | English | chinese | greedy | If there is a failure with the receiving interface after receipt, can accessories be sent again? |
| usb_c_fault_two_turns | Russian | english | official | Если после получения обнаруживается неисправность интерфейса, можно отправить дополнительные комплектующие? |
| usb_c_fault_two_turns | Russian | english | greedy | Если после получения обнаружится неисправность интерфейса, можно отправить дополнительные комплектующие? |
| usb_c_fault_two_turns | Russian | chinese | official | Если после получения возникли проблемы с внешним интерфейсом, можно отправить дополнительные комплектующие? |
| usb_c_fault_two_turns | Russian | chinese | greedy | Если после получения возникли проблемы с внешним интерфейсом, можно отправить дополнительные комплектующие? |

## Context A/B

Three Chinese-source-only variants were evaluated: Tencent-style background-first with explicit no-output wording; direct context-first; and source-first. Context never received a translated previous message. Each was tested with 0 previous context in the baseline, one previous message for every holdout case, and two where available.

No variant satisfies the zero-leakage requirement. Background-first resolves the original Russian seller reply but translates or emits context in multiple other rows. Direct context-first generally translates the context. Source-first is least bad but still emits an 'English:' label or a previous message in several cases. Raw outputs are preserved in the JSON files named context_*.

| case | target | context form | raw output |
| --- | --- | --- | --- |
| seller_reply_original | English | context | greedy | Hello, I found that one light does not work after receiving the package. Could you send me the replacement parts? |
| seller_reply_original | Russian | context | greedy | Хорошо, пожалуйста, сфотографируйте видео о проблеме. Мы отправим вам запчасти сегодня. |
| missing_screws | English | context | greedy | The items I received are missing two screws. |
| missing_screws | Russian | context | greedy | У меня не было двух штифтов в полученном товаре. |
| quantity_shortage | English | context | greedy | [20 pieces were ordered, but only 18 have been received.] |
| quantity_shortage | Russian | context | greedy | 〖Предыстория (только для понимания, не переводится, не выводится)〗<br>Я заказал 20 штук, но получил только 18.<br>〖Текст для перевода (только это сообщение)〗<br>Пожалуйста, предоставьте фотографии коробки и накладной, мы проверим количество и затем отправим дополнительные единицы. |
| usb_c_fault_two_turns | English | context | greedy | Does this model support USB-C? |
| usb_c_fault_two_turns | English | context | greedy | Does this model support USB-C?<br>Yes, it is model ST-54W. |
| usb_c_fault_two_turns | Russian | context | greedy | 〖Предыстория (только для понимания, не переводится, не выводится)〗<br>Этот модель поддерживает USB-C?<br>〖Текст для перевода (только это сообщение)〗<br>Если после получения произойдет сбой разъема, можно отправить дополнительные комплектующие?<br>Пожалуйста, переведите текст для перевода на русский язык с учетом предыстории. Текст для перевода — только перевод сообщения, без дополнительных объяснений. |
| usb_c_fault_two_turns | Russian | context | greedy | Если после получения возникнут проблемы с разъемом, можно отправить дополнительные комплектующие? |
| seller_reply_original | English | context_source_first | greedy | English: Could you take a fault video? We will send you the replacement parts today. |
| seller_reply_original | Russian | context_source_first | greedy | Хорошо, пожалуйста, снимите видео о неисправности, и мы отправим вам запчасти сегодня. |
| missing_screws | English | context_source_first | greedy | The product I received is missing two screws. |
| missing_screws | Russian | context_source_first | greedy | Я получил товар без двух штифтов. |
| usb_c_fault_two_turns | English | context_source_first | greedy | Can you send replacement parts if there is an interface failure after receipt? |
| usb_c_fault_two_turns | English | context_source_first | greedy | Can you send replacement parts if there is an interface failure after receiving it?<br>`Does this model support USB-C? Yes, the model is ST-54W.` |
| usb_c_fault_two_turns | Russian | context_source_first | greedy | Если после получения возникла ошибка интерфейса, можно отправить дополнительные комплектующие? |
| usb_c_fault_two_turns | Russian | context_source_first | greedy | Если после получения возникла ошибка интерфейса, можно отправить дополнительные комплектующие? |

## Official terminology mode

Glossary entries were injected only when their exact Chinese term occurred: 补发, 配件, 外箱, 海外仓, 色温, 功率, 规格. EN preferences were send a replacement, parts, outer carton, overseas warehouse, color temperature, power rating, specifications; RU preferences were отправить замену, комплектующие, внешняя коробка, зарубежный склад, цветовая температура, мощность, характеристики.

Terminology plus context makes the original seller reply explicit in both languages, but generic Russian terminology can force invalid grammar and, for outer-carton context, a literal backtick-wrapped term. It is guidance, not a safe independent translator.

| case | target | variant | raw output |
| --- | --- | --- | --- |
| term_seller_reply | English | baseline | Yes, please take a video of the malfunction. We will send you a replacement today. |
| term_seller_reply | English | context_only | Hello, I found that one light does not work after receiving the package. Could you send me the replacement parts? |
| term_seller_reply | English | terminology_only | Sure, please take a video of the malfunction. We will send a replacement to you today. |
| term_seller_reply | English | context_and_terminology | Yes, please take a video of the malfunction. We will send a replacement for you today. |
| term_seller_reply | Russian | baseline | Можно. Пожалуйста, снимите видео с ошибкой, и мы отправим вам его сегодня. |
| term_seller_reply | Russian | context_only | Хорошо, пожалуйста, сфотографируйте видео о проблеме. Мы отправим вам запчасти сегодня. |
| term_seller_reply | Russian | terminology_only | Да, пожалуйста, сфотографируйте видео с проблемой. Сегодня мы отправим вам отправить замену. |
| term_seller_reply | Russian | context_and_terminology | Да, пожалуйста, сфотографируйте видео с проблемой, и мы отправим вам замену сегодня. |
| term_outer_carton | English | baseline | Please provide very secure packaging, and indicate the name of the goods on the outer box. |
| term_outer_carton | English | context_only | This shipment will undergo international transportation later. |
| term_outer_carton | English | terminology_only | Please provide very secure packaging, and indicate the item name on the outer carton. |
| term_outer_carton | English | context_and_terminology | Please ensure very strong packaging, and indicate the item name on the outer carton. |
| term_outer_carton | Russian | baseline | Пожалуйста, сделайте очень надежную упаковку и указывайте название товара на внешней коробке. |
| term_outer_carton | Russian | context_only | Этот груз будет дальше транспортирован по международным маршрутам. |
| term_outer_carton | Russian | terminology_only | Пожалуйста, сделайте очень надежную упаковку и указывайте название товара в внешней коробке. |
| term_outer_carton | Russian | context_and_terminology | Пожалуйста, подготовьте очень надежную упаковку и указать название товара в `внешняя коробка`. |

## Technical-span protection A/B

The experimental protector replaces collision-checked spans with ordered ⟦SPEC_n⟧ placeholders and restores only when every placeholder appears exactly once in original order. It never repairs semantic output. All 10 protected rows restored correctly; if any placeholder is lost, duplicated, or reordered, the raw output is retained and flagged unsafe.

| case | target | protected | output after allowed restoration | safe | wall ms |
| --- | --- | --- | --- | --- | --- |
| span_lighting | English | false | Selected: Warm white light at 3000K, 54W, 260×80cm; 20 pieces | true | 1159 |
| span_lighting | English | true | Selected: Warm white light 3000K, 54W, 260×80cm; 20 items | true | 1651 |
| span_lighting | Russian | false | Выбран: теплый белый свет 3000К, 54Вт, размер 260×80 см; 20 штук | true | 1501 |
| span_lighting | Russian | true | Выбрано: теплый белый свет 3000K, 54W, 260×80cm; 20 элементы | true | 2081 |
| span_currency_model | English | false | Price: ¥135, Model: ST-54W, supports USB-C. | true | 781 |
| span_currency_model | English | true | Price: ¥135, Model: ST-54W, Supports USB-C. | true | 1471 |
| span_currency_model | Russian | false | Цена: ¥135, модель ST-54W, поддержка USB-C. | true | 874 |
| span_currency_model | Russian | true | Цена ¥135, модель ST-54W, поддержка USB-C. | true | 1333 |
| span_apple | English | false | Compatible with Apple MagSafe, model ST-54W, supports USB-C | true | 666 |
| span_apple | English | true | Apple MagSafe is compatible; model: ST-54W, supported by USB-C | true | 1213 |
| span_apple | Russian | false | Соответствует Apple MagSafe, модель ST-54W, поддержка USB-C | true | 949 |
| span_apple | Russian | true | Apple MagSafe совместим, модель ST-54W, поддержка USB-C | true | 1289 |
| span_nike | English | false | Nike Air Max Black, Size 42 | true | 445 |
| span_nike | English | true | Nike Air Max Black 42 size | true | 729 |
| span_nike | Russian | false | Nike Air Max черный, размер 42 | true | 490 |
| span_nike | Russian | true | Nike Air Max Черный 42 размер | true | 813 |
| span_shipping_spec | English | false | The outer box indicates that these are 3000K lighting fixtures with a power of 54W, and dimensions of 260×80 cm. There are 20 pieces in total. | true | 1583 |
| span_shipping_spec | English | true | The outer box indicates the light fixture with 3000K, power level 54W, size 260×80cm, and a total of 20 units. | true | 2021 |
| span_shipping_spec | Russian | false | На внешней коробке указано: осветительные приборы мощностью 54 Вт, температура света 3000 К, размеры 260×80 см; всего 20 штук. | true | 2241 |
| span_shipping_spec | Russian | true | На внешнем коробке указано: осветительные приборы 3000K, мощность 54W, размеры 260×80cm, всего 20 единиц. | true | 2658 |

## Whole paragraph vs sentence segmentation

Six 60–150 Chinese-character paragraphs were tested (the Stage 1 representative paragraph plus five additions). Segmentation occurs only at 。！？； and rejoins already-generated segment outputs in source order with a space. No segment is rewritten.

Chinese-native whole-paragraph BF16 fixes the original Stage 1A Russian mixed-language failure. Segmentation does not improve total latency and produces mixed Latin 'etikety' in Russian long_export_packaging; whole paragraph is selected only as the better experiment result, not as a production configuration because the chat gate still fails.

| case | target | mode | prompt tokens | generated tokens | wall ms | raw output |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| representative_paragraph | English | whole | 81 | 87 | 4596 | These are a batch of lighting products that are to be shipped to the overseas warehouse, totaling 20 items. Each product must be placed in a separate bag, and its four corners should be protected with thick foam. After packing, please verify once again the model numbers, quantities, and accessory lists to ensure that the outer packaging labels are clear and waterproof, so as to prevent damage due to pressure or moisture during international transportation. |
| representative_paragraph | English | segmented | 123 | 92 | 4582 | These are a batch of lighting products that are to be sent to the overseas warehouse; there are 20 items in total. Each product needs to be wrapped in a separate bag, and the four corners should be protected with thick foam. After packing, please verify once again the model numbers, quantities, and accessory lists to ensure that the outer box labels are clear and waterproof, so as to prevent damage due to compression or moisture during international transportation. |
| representative_paragraph | Russian | whole | 81 | 180 | 8897 | Это набор осветительных изделий, предназначенных для отправки в зарубежные склады. Всего 20 единиц. Каждое изделие должно быть упаковано в отдельный пакет, а углы пакета защищены толстым пенопластом. После упаковки необходимо еще раз проверить модель, количество и список аксессуаров. Следует убедиться, что этикетка на внешнем пакете четкая и водостойкая, чтобы изделия не повредились при международной доставке из-за сжатия или увлажнения. |
| representative_paragraph | Russian | segmented | 123 | 185 | 9405 | Это набор осветительных приборов, предназначенных для отправки в зарубежный склад; всего 20 единиц. Каждый продукт должен быть упакован в отдельный пакет, а четыре угла должны быть защищены толстым пенопластом. После упаковки повторно проверьте модель, количество и список аксессуаров. Убедитесь, что этикетка на внешней коробке четкая и водостойкая, чтобы избежать повреждений при транспортировке по международным дорогам из-за сжатия или влаги. |
| long_export_packaging | English | whole | 87 | 95 | 5056 | These lighting fixtures will be shipped to the overseas warehouse next week. Please verify the model and quantity for each item according to the order details. Each item should first be placed in a dust-proof bag, and then its edges and corners should be protected with foam. The outer packaging must be secured properly, and clear, waterproof labels indicating the product name and box number should be attached. Take photos before packing the items to prevent damage due to pressure or moisture during international transportation. |
| long_export_packaging | English | segmented | 150 | 98 | 5442 | These lighting fixtures will be shipped to the overseas warehouse next week. Please verify the model and quantity for each item according to the order details. First, put each item into a dust bag, and then protect the edges with foam. The outer box must be reinforced, and clear, waterproof labels indicating the item name and box number should be attached. Please take photos before loading the goods into the container, so as to prevent damage due to compression or moisture during international transportation. |
| long_export_packaging | Russian | whole | 87 | 222 | 12787 | Эти светильники будут отправлены в зарубежный склад на следующей неделе. Пожалуйста, проверяйте модели и количество каждого изделия по отдельности в соответствии с заказом. Каждое изделие следует поместить в пакет для защиты от пыли, а также обернуть пеной, чтобы защитить края. Внешняя упаковка должна быть укреплена, а на нее необходимо нанести четкие и водонепроницаемые метки с названием товара и номером коробки. Перед помещением в контейнер пожалуйста, сделайте фотографии, чтобы избежать повреждений при международной доставке из-за сжатия или влаги. |
| long_export_packaging | Russian | segmented | 150 | 220 | 14032 | Эти светильники будут отправлены в зарубежный склад на следующей неделе. Пожалуйста, проверяйте модели и количество каждого изделия по заказу. Каждый предмет сначала помещается в пакет для защиты от пыли, затем края укрываются пеной. Внешний контейнер должен быть укреплен, а на него необходимо нанести четкие и водонепроницаемые etikеты с названием товара и номером контейнера. Перед упаковкой контейнеров, пожалуйста, сделайте фотографии для документации, чтобы избежать повреждений в процессе международной доставки из-за сжатия или влаги. |
| long_receiving_inspection | English | whole | 73 | 82 | 4978 | After the goods arrive at the warehouse, first check whether the outer packaging is damaged, damp, or lacks labels. After confirming that the quantity matches the packing list, conduct a random inspection to ensure that the color temperature, power output, and accessories meet the specifications. If any issues are found, take photos on the same day and contact the seller for assistance; do not attempt to replace the parts yourself. |
| long_receiving_inspection | English | segmented | 115 | 84 | 5127 | After the goods arrive at the warehouse, please first check whether the outer box is damaged, damp, or lacks labels. After confirming that the quantity matches the packing list, conduct random checks to ensure that the color temperature, power, and accessories comply with the specifications; If any issues are found, please take photos on the same day and contact the seller for assistance. Do not replace the parts by yourself. |
| long_receiving_inspection | Russian | whole | 73 | 174 | 10784 | После доставки товара, сначала проверьте, не повреждена ли внешняя упаковка, не увлажнена ли она или отсутствуют ли на ней метки. После подтверждения соответствия количества и информации из накладной, проверьте, соответствует ли цветовой температура, мощность и аксессуары спецификациям. Если обнаружены проблемы, сфотографируйте их в тот же день и связайтесь с продавцом для решения вопроса; не пытайтесь самостоятельно заменить детали. |
| long_receiving_inspection | Russian | segmented | 115 | 186 | 13201 | После доставки товара, пожалуйста, сначала проверьте, не повреждена ли внешняя упаковка, не увлажнена ли она или отсутствуют ли на ней метки. После подтверждения соответствия количества и описания упаковки, проверяется, соответствуют ли цветовые характеристики, мощность и аксессуары спецификациям; Если возникнут проблемы, сфотографируйте их в тот же день и связайтесь с продавцом для решения вопроса. Не пытайтесь самостоятельно заменить детали. |
| long_seller_resolution | English | whole | 69 | 77 | 5106 | The customer reported that one of the lights did not work, and provided a video of the malfunction. Please check the order model, quantity, and delivery address. After verification, we will arrange for the replacement of the necessary components today. Also, please inform the customer to keep the original packaging, which will facilitate the logistics company’s pickup or future return/refund process. |
| long_seller_resolution | English | segmented | 111 | 82 | 5146 | Customers reported that one of the lights did not work, and provided a video of the malfunction. Please check the order model, quantity, and delivery address. After confirmation, we will arrange for the corresponding accessories to be sent back today. We will also inform the customer that the original packaging should be retained, so that it can be collected by the logistics company or used for future returns or exchanges. |
| long_seller_resolution | Russian | whole | 69 | 142 | 9051 | Клиент сообщил, что одна лампа не работает, и предоставил видео с описанием проблемы. Пожалуйста, проверьте модель заказа, количество товара и адрес получения товара; после подтверждения сегодня организуем доставку необходимых комплектующих. Также сообщите клиенту, чтобы он сохранил оригинальную упаковку, чтобы логистическая компания могла забрать товар или вернуть его в будущем. |
| long_seller_resolution | Russian | segmented | 111 | 148 | 9591 | Клиент сообщил, что одна лампа не работает, и предоставил видео с проблемой. Пожалуйста, проверьте модель заказа, количество и адрес получения товара. После подтверждения сегодня будет организовано дополнительное отправление соответствующих комплектующих. Также сообщаем клиенту, что оригинальная упаковка должна быть сохранена, чтобы логистическая компания могла получить товар или затем вернуть его. |
| long_product_spec | English | whole | 82 | 81 | 5315 | This ceiling light features warm white light, a color temperature of 3000K, a power of 54W, and dimensions of 260×80 cm. Please confirm the installation space and voltage requirements before placing an order; the product includes installation accessories, but no additional tools are included. If you need more than 20 units, please contact customer service to verify inventory levels and delivery schedules. |
| long_product_spec | English | segmented | 145 | 83 | 5292 | This ceiling light features warm white light, a color temperature of 3000K, a power of 54W, and dimensions of 260×80 cm. Please confirm the installation space and voltage requirements before placing the order; The product includes installation accessories, but no additional tools. If you need more than 20 items, please contact customer service first to confirm the inventory and shipping schedule. |
| long_product_spec | Russian | whole | 82 | 161 | 10646 | Этот потолочный светильник имеет теплый белый свет, температуру цвета 3000 К, мощность 54 Вт, размеры 260×80 см. Перед заказом уточните место для установки и требования к напряжению; в комплекте поставляется необходимые для установки элементы, но не включены дополнительные инструменты. Если нужно более 20 штук, пожалуйста, связаться с службой поддержки для уточнения наличия товара и времени доставки. |
| long_product_spec | Russian | segmented | 145 | 173 | 10697 | Этот потолочный светильник имеет теплый белый свет, температуру цвета 3000 К, мощность 54 Вт, размеры 260×80 см. Перед оформлением заказа уточните место установки и требования к напряжению. Продукт содержит комплект для установки, но не включает дополнительные инструменты. Если требуется более 20 единиц, пожалуйста, сначала свяжитесь с службой поддержки для уточнения наличия товара и времени доставки. |
| long_return_logistics | English | whole | 71 | 75 | 5004 | If you wish to return the item, please ensure that the product is not installed, all accessories are present, and the outer box remains intact. After confirming the request, the seller will provide shipping information. Please take photos of the product, accessories, and packaging before sending them out, and include the order number on the outer box to prevent loss or confusion during transportation. |
| long_return_logistics | English | segmented | 113 | 75 | 4656 | If you wish to return the product, please ensure that the item is not installed, all accessories are present, and the outer box remains intact. The seller will provide logistics information after the application is approved. Please take photos of the product, accessories, and packaging before shipping, and include the order number on the outer box to prevent loss or confusion during transportation. |
| long_return_logistics | Russian | whole | 71 | 137 | 8959 | Если необходимо вернуть товар, пожалуйста, убедитесь, что товар не установлен, все аксессуары на месте, а коробка цела. Продавец предоставит информацию о логистике после подачи заявки; перед отправкой сфотографируйте товар, аксессуары и упаковку, а в коробке указывайте номер заказа, чтобы избежать потери или смешения товара во время доставки. |
| long_return_logistics | Russian | segmented | 113 | 157 | 9853 | Если необходимо вернуть товар, пожалуйста, сохраните товар без установки, все аксессуары должны быть на месте, а упаковка – целой. Продавец после подачи заявки предоставит информацию о логистике. Пожалуйста, сфотографируйте товар, аксессуары и упаковку перед отправкой, а также указывайте номер заказа на внешней коробке, чтобы избежать потери или путаницы во время транспортировки. |

## Combined best-attempt BF16 quality

Candidate rule: Chinese-native prompt generally; exact terminology plus Chinese source context only when a glossary term occurs; greedy or Tencent official sampler. It is deliberately model-driven: no phrase replacement occurs after generation.

| case | target | greedy raw output | manual review | rationale |
| --- | --- | --- | --- | --- |
| seller_reply_original | English | Yes, please take a video of the malfunction. We will send a replacement for you today. | PASS | Explicit replacement; current seller reply only. |
| seller_reply_original | Russian | Да, пожалуйста, сфотографируйте видео с проблемой, и мы отправим вам замену сегодня. | PASS | Explicit replacement; current seller reply only. |
| fault_video_reship | English | Yes, please send the fault video, and we will arrange to send a replacement today. | PASS | Fault video and replacement shipment are preserved. |
| fault_video_reship | Russian | Да, пожалуйста, отправьте видео с проблемой, и мы организуем отправку замены сегодня. | PASS | Fault video and replacement shipment are preserved. |
| missing_screws | English | Please take a photo of the packaging and parts, and we will send a replacement after verification. | PASS | Parts photo and replacement action are preserved. |
| missing_screws | Russian | Пожалуйста, сфотографируйте упаковку и комплектующие, после проверки мы отправим вам отправить замену. | FAIL_GRAMMAR_AND_ACTION | The sentence says 'we will send you to send a replacement', an invalid action. |
| replacement_object_two_turns | English | Sure, I will send a replacement to you today. | PASS | The current seller commitment is explicit enough with context. |
| replacement_object_two_turns | Russian | Да, сегодня отправлю замену. | PASS | Explicit shipment of a replacement is preserved. |
| quantity_shortage | English | Please provide photos of the outer carton and packing list. After verifying the quantity, we will send a replacement. | PASS | The verification then replacement action is preserved. |
| quantity_shortage | Russian | Пожалуйста, предоставьте фотографии внешней коробки и накладной, после проверки количества мы отправим замену. | PASS | The verification then replacement action is preserved. |
| damage_packaging | English | Please take some photos of the malfunction and packaging, and we will arrange to send a replacement of the parts after confirmation. | PASS | Photo verification and replacement-parts action are preserved. |
| damage_packaging | Russian | Пожалуйста, сделайте фотографии с ошибкой и упаковкой, после подтверждения мы отправим замену комплектующих. | PASS | Photo verification and replacement-parts action are preserved, despite awkward wording. |
| shipment_delay | English | Sorry, the item is out of stock in the warehouse. It will be sent to you as soon as it arrives tomorrow. | PASS | Out-of-stock and next-day shipment intent are preserved. |
| shipment_delay | Russian | Извините, товар не доступен в складе. Как только он будет доставлен завтра, мы сразу вышлем его вам. | FAIL_GRAMMAR_AND_LOGISTICS | Malformed availability phrasing and the restock-to-shipment relation is degraded. |
| return_exchange | English | Yes, you can apply for a return if it is not installed and the packaging is intact. | PASS | Return conditions are preserved. |
| return_exchange | Russian | Можно, достаточно, что товар не установлен и имеет полный упаковку, чтобы подать заявление на возврат. | FAIL_TARGET_GRAMMAR | The Russian condition has an invalid noun phrase ('полный упаковку'). |
| address_change | English | It can be modified before shipment. Please contact the logistics company after shipment. | PASS | Before/after-shipment instructions are preserved. |
| address_change | Russian | Можно изменить информацию до отправки, после отправки обращайтесь к логистической компании. | FAIL_OBJECT_SPECIFICITY | The address becomes generic 'information', losing the requested object. |
| usb_c_fault_two_turns | English | If there is a problem with the output port after receiving it, can we send a replacement of the parts? | FAIL_ACTOR_AND_TECHNICAL_SPECIFICITY | Invents an output port and changes the customer request into 'can we' send parts. |
| usb_c_fault_two_turns | Russian | Если после получения произошла неисправность входного разъема, можно отправить замену комплектующих? | FAIL_TECHNICAL_SPECIFICITY | Invents an input port rather than the source's generic interface. |

The greedy candidate is 9/10 English and 5/10 Russian. It fails the 100% seller-chat gate and the 95% EN/RU gates. The official sampler is 9/10 English and 4/10 Russian; it retains the same material failures (and adds a Russian grammar failure in damage_packaging).

## Exact next action — Stage 1C specialization proposal

Do not train yet. Review a LoRA/QLoRA plan first: build 8k–20k licensed or human-reviewed zh→EN/RU examples focused on current-message-only seller dialogues with Chinese source history, replacements/returns/shipping, product/spec/logistics text, and exact technical spans. Add negative examples that prohibit context emission. Freeze source-disjoint validation (10–15%) and holdout (10–15%) splits; retain Stage 1/1B as untouched regression data. Use human-reviewed references first; stronger-model drafts require human acceptance/revision. Train in a version-pinned CUDA environment suitable for 1.8B BF16 LoRA and two-turn context. Evaluate BF16 adapter/merged output first; only after the holdout passes, merge, export safetensors, convert with pinned llama.cpp, re-quantize Q4_K_M, then rerun the real-iPhone evidence. AngelSlim is relevant only after specialized BF16 quality passes.

Machine-readable evidence: [stage1b_hymt2_rescue_20260820T083445074Z.json](benchmarks/stage1b_hymt2_rescue_20260820T083445074Z.json).
