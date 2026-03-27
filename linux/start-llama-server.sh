#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-$ROOT_DIR/vendor/llama.cpp}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"
CONTEXT_SIZE="${CONTEXT_SIZE:-8192}"
PARALLEL="${PARALLEL:-1}"
GPU_LAYERS="${GPU_LAYERS:-auto}"
MODEL_PATH="${MODEL_PATH:-}"
HF_REPO="${HF_REPO:-}"

if [[ -z "$MODEL_PATH" && -z "$HF_REPO" ]]; then
  echo "Provide MODEL_PATH or HF_REPO." >&2
  exit 1
fi

find_server_bin() {
  local base_dir="$1"
  local candidates=(
    "$base_dir/build/bin/llama-server"
    "$base_dir/build/bin/Release/llama-server"
    "$base_dir/bin/llama-server"
    "$base_dir/bin/Release/llama-server"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

detect_backend_from_build() {
  local base_dir="$1"
  local cache_file="$base_dir/build/CMakeCache.txt"
  if [[ ! -f "$cache_file" ]]; then
    printf 'cpu\n'
    return 0
  fi

  if grep -q 'GGML_CUDA:BOOL=ON' "$cache_file"; then
    printf 'cuda\n'
    return 0
  fi

  if grep -q 'GGML_VULKAN:BOOL=ON' "$cache_file"; then
    printf 'vulkan\n'
    return 0
  fi

  printf 'cpu\n'
}

LLAMA_SERVER_BIN="$(find_server_bin "$LLAMA_CPP_DIR" || true)"
if [[ -z "$LLAMA_SERVER_BIN" ]]; then
  echo "Could not find llama-server under $LLAMA_CPP_DIR. Run ./linux/deploy-stack.sh first." >&2
  exit 1
fi

RESOLVED_BACKEND="$(detect_backend_from_build "$LLAMA_CPP_DIR")"
ARGS=(--host "$HOST" --port "$PORT" -c "$CONTEXT_SIZE" -np "$PARALLEL")
if [[ "$GPU_LAYERS" == "auto" ]]; then
  if [[ "$RESOLVED_BACKEND" != "cpu" ]]; then
    ARGS+=(-ngl 999)
  fi
elif [[ "$GPU_LAYERS" -gt 0 ]]; then
  ARGS+=(-ngl "$GPU_LAYERS")
fi

if [[ -n "$MODEL_PATH" ]]; then
  ARGS=(-m "$MODEL_PATH" "${ARGS[@]}")
else
  ARGS=(-hf "$HF_REPO" "${ARGS[@]}")
fi

printf 'Detected backend: %s\n' "$RESOLVED_BACKEND"
printf 'Starting llama-server with arguments:\n%s\n' "${ARGS[*]}"
exec "$LLAMA_SERVER_BIN" "${ARGS[@]}"
