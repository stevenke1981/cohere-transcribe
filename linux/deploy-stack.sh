#!/usr/bin/env bash
set -euo pipefail

PYTHON_EXE="${PYTHON_EXE:-python3}"
VENV_DIR="${VENV_DIR:-.venv}"
LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-vendor/llama.cpp}"
LLAMA_BACKEND="${LLAMA_BACKEND:-auto}"
SKIP_PYTHON_SETUP="${SKIP_PYTHON_SETUP:-0}"
SKIP_LLAMA_BUILD="${SKIP_LLAMA_BUILD:-0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PATH="$ROOT_DIR/$VENV_DIR"
LLAMA_CPP_PATH="$ROOT_DIR/$LLAMA_CPP_DIR"

step() {
  printf '\n==> %s\n' "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

resolve_llama_backend() {
  local requested="$1"
  if [[ "$requested" != "auto" ]]; then
    printf '%s\n' "$requested"
    return 0
  fi

  if command -v nvcc >/dev/null 2>&1 || command -v nvidia-smi >/dev/null 2>&1 || [[ -n "${CUDA_HOME:-}" || -n "${CUDA_PATH:-}" ]]; then
    printf 'cuda\n'
    return 0
  fi

  if command -v vulkaninfo >/dev/null 2>&1 || [[ -n "${VULKAN_SDK:-}" ]]; then
    printf 'vulkan\n'
    return 0
  fi

  printf 'cpu\n'
}

install_torch() {
  local python_bin="$1"
  if command -v nvcc >/dev/null 2>&1 || command -v nvidia-smi >/dev/null 2>&1 || [[ -n "${CUDA_HOME:-}" || -n "${CUDA_PATH:-}" ]]; then
    step "Installing GPU-first PyTorch (CUDA), fallback to CPU on failure"
    if "$python_bin" -m pip install torch --index-url https://download.pytorch.org/whl/cu124; then
      return 0
    fi
    echo "CUDA PyTorch install failed, falling back to CPU/default torch." >&2
  fi

  step "Installing CPU/default PyTorch"
  "$python_bin" -m pip install torch
}

if [[ "$SKIP_PYTHON_SETUP" != "1" ]]; then
  require_cmd "$PYTHON_EXE"
  step "Creating Python virtual environment"
  "$PYTHON_EXE" -m venv "$VENV_PATH"

  step "Installing Cohere Transcribe dependencies"
  "$VENV_PATH/bin/python" -m pip install --upgrade pip setuptools wheel
  install_torch "$VENV_PATH/bin/python"
  "$VENV_PATH/bin/python" -m pip install -r "$ROOT_DIR/requirements.txt"
fi

if [[ "$SKIP_LLAMA_BUILD" != "1" ]]; then
  require_cmd git
  require_cmd cmake
  RESOLVED_BACKEND="$(resolve_llama_backend "$LLAMA_BACKEND")"

  step "Preparing llama.cpp source"
  if [[ ! -d "$LLAMA_CPP_PATH/.git" ]]; then
    mkdir -p "$(dirname "$LLAMA_CPP_PATH")"
    git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$LLAMA_CPP_PATH"
  else
    git -C "$LLAMA_CPP_PATH" pull --ff-only
  fi

  BUILD_DIR="$LLAMA_CPP_PATH/build"
  CMAKE_ARGS=(-S "$LLAMA_CPP_PATH" -B "$BUILD_DIR")
  case "$RESOLVED_BACKEND" in
    cuda)
      CMAKE_ARGS+=(-DGGML_CUDA=ON)
      ;;
    vulkan)
      CMAKE_ARGS+=(-DGGML_VULKAN=ON)
      ;;
    cpu)
      ;;
    *)
      echo "Unsupported LLAMA_BACKEND: $LLAMA_BACKEND" >&2
      exit 1
      ;;
  esac

  step "Configuring llama.cpp build ($RESOLVED_BACKEND)"
  cmake "${CMAKE_ARGS[@]}"

  step "Building llama-server"
  cmake --build "$BUILD_DIR" --config Release --target llama-server -j
fi

step "Completed"
cat <<EOF
Next steps:
  1. Start llama.cpp:      ./linux/start-llama-server.sh ...
  2. Start Cohere service: ./linux/start-cohere-transcribe.sh ...
EOF
