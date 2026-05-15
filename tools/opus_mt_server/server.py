from __future__ import annotations

import logging
import os
import time
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from opus_mt_engine import DEFAULT_MODEL_PATH, DEFAULT_TOKENIZER_NAME, OpusMTCT2Translator


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("opus_mt_server")

PROVIDER = "opus-mt-ct2"
MODEL_PATH = Path(os.environ.get("OPUS_MT_MODEL_PATH", DEFAULT_MODEL_PATH))
TOKENIZER_NAME = os.environ.get("OPUS_MT_TOKENIZER", DEFAULT_TOKENIZER_NAME)
DEVICE = os.environ.get("OPUS_MT_DEVICE", "auto")
COMPUTE_TYPE = os.environ.get("OPUS_MT_COMPUTE_TYPE", "auto")
BEAM_SIZE = int(os.environ.get("OPUS_MT_BEAM_SIZE", "4"))

app = FastAPI(
    title="ScreenTranslator OPUS-MT Local Server",
    version="0.1.0",
)

translator: OpusMTCT2Translator | None = None
startup_error: str | None = None


class TranslateBlock(BaseModel):
    id: str = Field(..., min_length=1)
    text: str = ""
    kind: str | None = None


class TranslateBlocksRequest(BaseModel):
    sourceLang: str = "zh"
    targetLang: str = "en"
    blocks: list[TranslateBlock] = Field(default_factory=list)


class TranslationItem(BaseModel):
    id: str
    sourceText: str
    translatedText: str
    latencyMs: int


class TranslateBlocksResponse(BaseModel):
    provider: str
    translations: list[TranslationItem]
    totalLatencyMs: int


@app.on_event("startup")
def load_model_once() -> None:
    global translator, startup_error

    try:
        start = time.perf_counter()
        translator = OpusMTCT2Translator(
            model_path=MODEL_PATH,
            tokenizer_name=TOKENIZER_NAME,
            device=DEVICE,
            compute_type=COMPUTE_TYPE,
            beam_size=BEAM_SIZE,
        )
        startup_error = None
        latency_ms = (time.perf_counter() - start) * 1000
        logger.info(
            "Loaded %s from %s in %.1f ms",
            PROVIDER,
            translator.model_path,
            latency_ms,
        )
    except Exception as error:  # noqa: BLE001 - expose as health/HTTP error.
        translator = None
        startup_error = str(error)
        logger.exception("Failed to load OPUS-MT model")


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "ok": translator is not None,
        "provider": PROVIDER,
        "modelPath": str(MODEL_PATH),
        "tokenizer": TOKENIZER_NAME,
        "device": DEVICE,
        "computeType": COMPUTE_TYPE,
        "error": startup_error,
    }


@app.post("/translateBlocks", response_model=TranslateBlocksResponse)
def translate_blocks(request: TranslateBlocksRequest) -> TranslateBlocksResponse:
    if request.sourceLang.lower() != "zh" or request.targetLang.lower() != "en":
        raise HTTPException(
            status_code=400,
            detail="Only sourceLang=zh and targetLang=en are supported in this POC.",
        )

    if translator is None:
        raise HTTPException(
            status_code=503,
            detail=startup_error or "Model is not loaded.",
        )

    start = time.perf_counter()
    texts = [block.text for block in request.blocks]

    try:
        translated = translator.translate_texts(texts)
    except Exception as error:  # noqa: BLE001 - return a clean API error.
        logger.exception("Translation failed")
        raise HTTPException(status_code=500, detail=str(error)) from error

    total_latency_ms = int(round((time.perf_counter() - start) * 1000))
    logger.info(
        "Translated %d blocks in %d ms",
        len(request.blocks),
        total_latency_ms,
    )

    return TranslateBlocksResponse(
        provider=PROVIDER,
        translations=[
            TranslationItem(
                id=block.id,
                sourceText=block.text,
                translatedText=result.translated_text,
                latencyMs=int(round(result.latency_ms)),
            )
            for block, result in zip(request.blocks, translated)
        ],
        totalLatencyMs=total_latency_ms,
    )
