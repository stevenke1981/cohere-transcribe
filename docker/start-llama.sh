#!/usr/bin/env bash
set -euo pipefail

HOST="${LLAMA_HOST:-0.0.0.0}"
PORT="${LLAMA_PORT:-8080}"
CONTEXT_SIZE="${LLAMA_CONTEXT_SIZE:-8192}"
PARALLEL="${LLAMA_PARALLEL:-1}"
GPU_LAYERS="${LLAMA_GPU_LAYERS:-auto}"
MODEL_DIR="${LLAMA_MODEL_DIR:-/models}"
MODEL_FILE="${LLAMA_MODEL_FILE:-model.gguf}"
HF_REPO="${LLAMA_HF_REPO:-}"

ARGS=(--host "$HOST" --port "$PORT" -c "$CONTEXT_SIZE" -np "$PARALLEL")

gpu_available() {
  if [[ -e /dev/nvidiactl || -e /dev/nvidia0 ]]; then
    return 0
  fi

  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    return 0
  fi

  if [[ -n "${NVIDIA_VISIBLE_DEVICES:-}" && "${NVIDIA_VISIBLE_DEVICES}" != "void" && "${NVIDIA_VISIBLE_DEVICES}" != "none" ]]; then
    return 0
  fi

  return 1
}

if [[ "$GPU_LAYERS" == "auto" ]]; then
  if gpu_available; then
    ARGS+=(-ngl 999)
  fi
elif [[ "$GPU_LAYERS" -gt 0 ]]; then
  ARGS+=(-ngl "$GPU_LAYERS")
fi

MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
if [[ -f "$MODEL_PATH" ]]; then
  ARGS=(-m "$MODEL_PATH" "${ARGS[@]}")
elif [[ -n "$HF_REPO" ]]; then
  ARGS=(-hf "$HF_REPO" "${ARGS[@]}")
else
  echo "No local GGUF model found at $MODEL_PATH and LLAMA_HF_REPO is empty." >&2
  exit 1
fi

printf 'Starting llama-server with arguments:\n%s\n' "${ARGS[*]}"
exec llama-server "${ARGS[@]}"
