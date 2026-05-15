# OPUS-MT zh-en Local Server POC

This folder is a Mac-local proof of concept for translating grouped OCR blocks with
`Helsinki-NLP/opus-mt-zh-en` through CTranslate2. It is not integrated into the iOS
runtime yet.

The intended future path is:

1. iPhone Shortcut captures screenshot.
2. ScreenTranslator runs OCR and groups Chinese text blocks.
3. ScreenTranslator sends grouped blocks to a local Mac server on the LAN.
4. The Mac server returns English translations.
5. ScreenTranslator renders the translated overlay and returns Quick Look PNG.

## Setup

```bash
cd tools/opus_mt_server
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

`torch` is included because the CTranslate2 converter uses the Transformers model
weights during conversion. The runtime server uses CTranslate2 after conversion.

## Convert Model

```bash
bash convert_model.sh
```

Default output:

```text
tools/opus_mt_server/models/opus-mt-zh-en-ct2
```

Default quantization is `int8`, which is the safest first option for Apple Silicon
and Intel Macs. You can experiment later:

```bash
QUANTIZATION=int8_float16 FORCE=1 bash convert_model.sh
```

## CLI Test

Translate one phrase:

```bash
python translate_cli.py --text "网络错误，请重试"
```

Run the bundled phrase batch:

```bash
python translate_cli.py
```

Use a custom converted model path:

```bash
python translate_cli.py \
  --model-path ./models/opus-mt-zh-en-ct2 \
  --text "请在外箱上注明里面是什么货物，方便仓库识别。"
```

## Run Server

```bash
uvicorn server:app --host 0.0.0.0 --port 8766
```

Local endpoint:

```text
http://127.0.0.1:8766/translateBlocks
```

Health check:

```bash
curl http://127.0.0.1:8766/health
```

Translate blocks:

```bash
curl -s http://127.0.0.1:8766/translateBlocks \
  -H 'Content-Type: application/json' \
  -d '{
    "sourceLang": "zh",
    "targetLang": "en",
    "blocks": [
      {
        "id": "block_1",
        "text": "网络错误，请重试",
        "kind": "systemMessage"
      },
      {
        "id": "block_2",
        "text": "这批货物后续还有国际运输，请务必做好非常牢固的包装。",
        "kind": "chatBubble"
      }
    ]
  }' | python3 -m json.tool
```

## iPhone Note

When connecting from a physical iPhone later, `localhost` means the iPhone itself,
not your Mac. Use the Mac LAN IP instead, for example:

```text
http://192.168.1.23:8766/translateBlocks
```

The Mac and iPhone must be on the same network, and macOS firewall settings must
allow incoming connections for the Python/uvicorn process.

## Current Status

- Local tooling/backend only.
- No iOS runtime code is changed by this POC.
- No paid API, backend cloud service, Google, Azure, or OpenAI dependency.
- OPUS-MT sentence quality should be tested against real OCR blocks before any
  app integration work.
