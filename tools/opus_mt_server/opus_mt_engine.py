from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


DEFAULT_TOKENIZER_NAME = "Helsinki-NLP/opus-mt-zh-en"
DEFAULT_MODEL_PATH = Path(__file__).resolve().parent / "models" / "opus-mt-zh-en-ct2"


@dataclass(frozen=True)
class TranslationResult:
    source_text: str
    translated_text: str
    latency_ms: float


class OpusMTCT2Translator:
    def __init__(
        self,
        model_path: str | Path = DEFAULT_MODEL_PATH,
        tokenizer_name: str = DEFAULT_TOKENIZER_NAME,
        device: str = "auto",
        compute_type: str = "auto",
        beam_size: int = 4,
    ) -> None:
        self.model_path = Path(model_path).expanduser().resolve()
        self.tokenizer_name = tokenizer_name
        self.device = device
        self.compute_type = compute_type
        self.beam_size = beam_size

        if not self.model_path.exists():
            raise FileNotFoundError(
                f"Converted CTranslate2 model not found: {self.model_path}. "
                "Run: bash convert_model.sh"
            )

        from ctranslate2 import Translator
        from transformers import MarianTokenizer

        self.tokenizer = MarianTokenizer.from_pretrained(tokenizer_name)
        self.translator = Translator(
            str(self.model_path),
            device=device,
            compute_type=compute_type,
        )

    def translate_texts(self, texts: Iterable[str]) -> list[TranslationResult]:
        source_texts = [text or "" for text in texts]
        results: list[TranslationResult] = [
            TranslationResult(source_text=text, translated_text="", latency_ms=0.0)
            for text in source_texts
        ]
        non_empty_items = [
            (index, text.strip())
            for index, text in enumerate(source_texts)
            if text.strip()
        ]

        if not non_empty_items:
            return results

        start = time.perf_counter()
        source_tokens = [
            self.tokenizer.convert_ids_to_tokens(
                self.tokenizer.encode(text)
            )
            for _, text in non_empty_items
        ]
        translated_batches = self.translator.translate_batch(
            source_tokens,
            beam_size=self.beam_size,
        )
        total_latency_ms = (time.perf_counter() - start) * 1000
        per_item_latency_ms = total_latency_ms / max(len(non_empty_items), 1)

        for (index, source_text), translated in zip(non_empty_items, translated_batches):
            output_tokens = translated.hypotheses[0]
            output_ids = self.tokenizer.convert_tokens_to_ids(output_tokens)
            translated_text = self.tokenizer.decode(
                output_ids,
                skip_special_tokens=True,
                clean_up_tokenization_spaces=True,
            ).strip()
            results[index] = TranslationResult(
                source_text=source_text,
                translated_text=translated_text,
                latency_ms=per_item_latency_ms,
            )

        return results
