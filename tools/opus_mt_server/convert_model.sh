#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODEL_NAME="${MODEL_NAME:-Helsinki-NLP/opus-mt-zh-en}"
MODELS_DIR="${SCRIPT_DIR}/models"
OUTPUT_DIR="${OUTPUT_DIR:-${MODELS_DIR}/opus-mt-zh-en-ct2}"
QUANTIZATION="${QUANTIZATION:-int8}"

mkdir -p "${MODELS_DIR}"

if [[ -d "${OUTPUT_DIR}" && "${FORCE:-0}" != "1" ]]; then
  echo "Converted model already exists at: ${OUTPUT_DIR}"
  echo "Set FORCE=1 to remove it and convert again."
  exit 0
fi

if [[ -d "${OUTPUT_DIR}" && "${FORCE:-0}" == "1" ]]; then
  rm -rf "${OUTPUT_DIR}"
fi

echo "Converting ${MODEL_NAME}"
echo "Output: ${OUTPUT_DIR}"
echo "Quantization: ${QUANTIZATION}"

ct2-transformers-converter \
  --model "${MODEL_NAME}" \
  --output_dir "${OUTPUT_DIR}" \
  --quantization "${QUANTIZATION}"

echo "Done. Converted model is at: ${OUTPUT_DIR}"
