#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

from opus_mt_engine import DEFAULT_MODEL_PATH, DEFAULT_TOKENIZER_NAME, OpusMTCT2Translator


DEFAULT_PHRASES_FILE = Path(__file__).resolve().parent / "test_phrases.json"


def load_phrases(path: Path) -> list[str]:
    raw: Any = json.loads(path.read_text(encoding="utf-8"))

    if isinstance(raw, list):
        phrases: list[str] = []
        for item in raw:
            if isinstance(item, str):
                phrases.append(item)
            elif isinstance(item, dict) and isinstance(item.get("text"), str):
                phrases.append(item["text"])
        return phrases

    if isinstance(raw, dict) and isinstance(raw.get("phrases"), list):
        return [
            item
            for item in raw["phrases"]
            if isinstance(item, str)
        ]

    raise ValueError(f"Unsupported phrases JSON format: {path}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Translate Chinese text with a local OPUS-MT zh-en CTranslate2 model."
    )
    parser.add_argument(
        "--text",
        action="append",
        help="Chinese text to translate. Can be passed multiple times.",
    )
    parser.add_argument(
        "--phrases-file",
        type=Path,
        default=DEFAULT_PHRASES_FILE,
        help="JSON file with test phrases. Used when --text is omitted.",
    )
    parser.add_argument(
        "--model-path",
        type=Path,
        default=DEFAULT_MODEL_PATH,
        help="Path to converted CTranslate2 model directory.",
    )
    parser.add_argument(
        "--tokenizer",
        default=DEFAULT_TOKENIZER_NAME,
        help="Hugging Face tokenizer/model name.",
    )
    parser.add_argument(
        "--device",
        default="auto",
        help="CTranslate2 device, for example auto, cpu, cuda.",
    )
    parser.add_argument(
        "--compute-type",
        default="auto",
        help="CTranslate2 compute type, for example auto, int8, int8_float16.",
    )
    parser.add_argument(
        "--beam-size",
        type=int,
        default=4,
        help="Beam size for translation.",
    )
    args = parser.parse_args()

    phrases = args.text if args.text else load_phrases(args.phrases_file)

    load_start = time.perf_counter()
    translator = OpusMTCT2Translator(
        model_path=args.model_path,
        tokenizer_name=args.tokenizer,
        device=args.device,
        compute_type=args.compute_type,
        beam_size=args.beam_size,
    )
    load_latency_ms = (time.perf_counter() - load_start) * 1000
    print(f"Loaded model: {translator.model_path}")
    print(f"Load latency: {load_latency_ms:.1f} ms")
    print()

    batch_start = time.perf_counter()
    results = translator.translate_texts(phrases)
    total_latency_ms = (time.perf_counter() - batch_start) * 1000

    for result in results:
        print(f"Source: {result.source_text}")
        print(f"Translation: {result.translated_text}")
        print(f"Latency: {result.latency_ms:.1f} ms")
        print("-" * 72)

    print(f"Batch total latency: {total_latency_ms:.1f} ms")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
