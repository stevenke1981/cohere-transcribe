#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_EXE="${PYTHON_EXE:-$ROOT_DIR/.enuv/bin/python}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-9000}"
MODEL_ID="${MODEL_ID:-CohereLabs/cohere-transcribe-03-2026}"
LANGUAGE="${LANGUAGE:-en}"
DEVICE="${DEVICE:-auto}"
BATCH_SIZE="${BATCH_SIZE:-8}"
COMPILE_ENCODER="${COMPILE_ENCODER:-false}"
PIPELINE_DETOKENIZATION="${PIPELINE_DETOKENIZATION:-false}"

if [[ ! -x "$PYTHON_EXE" ]]; then
  echo "Python executable not found: $PYTHON_EXE. Run ./linux/deploy-stack.sh first." >&2
  exit 1
fi

export PYTHONPATH="$ROOT_DIR"
export COHERE_MODEL_ID="$MODEL_ID"
export COHERE_DEFAULT_LANGUAGE="$LANGUAGE"
export COHERE_DEVICE="$DEVICE"
export COHERE_BATCH_SIZE="$BATCH_SIZE"
export COHERE_COMPILE="$COMPILE_ENCODER"
export COHERE_PIPELINE_DETOKENIZATION="$PIPELINE_DETOKENIZATION"

printf 'Starting Cohere Transcribe service on %s:%s\n' "$HOST" "$PORT"
printf 'Model: %s\nLanguage: %s\nDevice: %s\n' "$MODEL_ID" "$LANGUAGE" "$DEVICE"
exec "$PYTHON_EXE" -m uvicorn app.cohere_server:app --host "$HOST" --port "$PORT"
