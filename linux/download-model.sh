#!/usr/bin/env bash
set -euo pipefail

# Downloads either:
#   1. A single GGUF file for llama.cpp, or
#   2. A full Hugging Face model snapshot for transformer-style models such as
#      CohereLabs/cohere-transcribe-03-2026.
#
# Usage:
#   HF_REPO=ggml-org/gemma-3-1b-it-GGUF ./linux/download-model.sh
#   HF_REPO=ggml-org/gemma-3-1b-it-GGUF HF_FILE=gemma-3-1b-it-Q4_K_M.gguf ./linux/download-model.sh
#   HF_REPO=CohereLabs/cohere-transcribe-03-2026 HF_SNAPSHOT=1 ./linux/download-model.sh
#
# Environment variables:
#   HF_REPO        Hugging Face repo (required, e.g. owner/repo-name)
#   HF_FILE        Filename inside the repo (single-file download mode)
#   HF_SNAPSHOT    1/true/yes/on to force full snapshot download
#   MODEL_DIR      Destination directory
#                  - file mode default:        <repo-root>/models
#                  - auto/snapshot default:    <repo-root>/models/<owner--repo>
#   HF_TOKEN       Hugging Face token for gated models (optional)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="${ROOT_DIR}/.venv/bin/python"
HF_REPO="${HF_REPO:-}"
HF_FILE="${HF_FILE:-}"
HF_SNAPSHOT="${HF_SNAPSHOT:-}"
MODEL_DIR="${MODEL_DIR:-}"

if [[ -z "$HF_REPO" ]]; then
  echo "Usage: HF_REPO=owner/repo-name $0" >&2
  echo "       HF_REPO=owner/repo-name HF_FILE=model.gguf $0" >&2
  echo "       HF_REPO=CohereLabs/cohere-transcribe-03-2026 HF_SNAPSHOT=1 $0" >&2
  exit 1
fi

is_truthy() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

repo_slug() {
  local repo="$1"
  printf '%s\n' "${repo//\//--}"
}

ensure_model_dir() {
  local mode="$1"
  if [[ -n "$MODEL_DIR" ]]; then
    printf '%s\n' "$MODEL_DIR"
    return 0
  fi

  if [[ "$mode" == "file" ]]; then
    printf '%s/models\n' "$ROOT_DIR"
  else
    printf '%s/models/%s\n' "$ROOT_DIR" "$(repo_slug "$HF_REPO")"
  fi
}

download_via_hf_cli() {
  local python_bin="$1"
  local repo="$2"
  local file="$3"
  local mode="$4"
  local dest_dir="$5"

  if [[ -n "${HF_TOKEN:-}" ]]; then
    "$python_bin" -c "
import huggingface_hub, os
huggingface_hub.login(token=os.environ['HF_TOKEN'], add_to_git_credential=False)
" 2>/dev/null || true
  fi

  if [[ "$mode" == "snapshot" ]]; then
    "$python_bin" -c "
import huggingface_hub
path = huggingface_hub.snapshot_download(
    repo_id='$repo',
    local_dir='$dest_dir',
    local_dir_use_symlinks=False,
)
print(path)
"
    return 0
  fi

  if [[ -n "$file" ]]; then
    "$python_bin" -c "
import huggingface_hub
path = huggingface_hub.hf_hub_download(
    repo_id='$repo',
    filename='$file',
    local_dir='$dest_dir',
    local_dir_use_symlinks=False,
)
print(path)
"
    return 0
  fi

  "$python_bin" -c "
import huggingface_hub
import sys

api = huggingface_hub.HfApi()
files = sorted(f.rfilename for f in api.list_repo_files('$repo'))
gguf_files = [name for name in files if name.endswith('.gguf')]

if gguf_files:
    chosen = gguf_files[0]
    print(f'Auto-selected GGUF file: {chosen}', file=sys.stderr)
    path = huggingface_hub.hf_hub_download(
        repo_id='$repo',
        filename=chosen,
        local_dir='$dest_dir',
        local_dir_use_symlinks=False,
    )
    print(path)
elif 'config.json' in files:
    print('Auto-selected full snapshot download for transformer model.', file=sys.stderr)
    path = huggingface_hub.snapshot_download(
        repo_id='$repo',
        local_dir='$dest_dir',
        local_dir_use_symlinks=False,
    )
    print(path)
else:
    print(f'No .gguf files and no config.json found in {repo}.', file=sys.stderr)
    sys.exit(1)
"
}

download_via_curl() {
  local repo="$1"
  local file="$2"
  local dest_dir="$3"
  local dest="$dest_dir/$file"
  local url="https://huggingface.co/${repo}/resolve/main/${file}"
  local curl_args=(-L --progress-bar -o "$dest")
  if [[ -n "${HF_TOKEN:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${HF_TOKEN}")
  fi
  mkdir -p "$(dirname "$dest")"
  echo "Downloading $url -> $dest" >&2
  curl "${curl_args[@]}" "$url"
  printf '%s\n' "$dest"
}

if is_truthy "$HF_SNAPSHOT"; then
  DOWNLOAD_MODE="snapshot"
elif [[ -n "$HF_FILE" ]]; then
  DOWNLOAD_MODE="file"
else
  DOWNLOAD_MODE="auto"
fi

TARGET_DIR="$(ensure_model_dir "$DOWNLOAD_MODE")"
mkdir -p "$TARGET_DIR"

if [[ -x "$VENV_PYTHON" ]]; then
  DEST="$(download_via_hf_cli "$VENV_PYTHON" "$HF_REPO" "$HF_FILE" "$DOWNLOAD_MODE" "$TARGET_DIR")"
elif [[ "$DOWNLOAD_MODE" == "file" && -n "$HF_FILE" ]] && command -v curl >/dev/null 2>&1; then
  DEST="$(download_via_curl "$HF_REPO" "$HF_FILE" "$TARGET_DIR")"
else
  echo "The project venv is required for auto-detection or full snapshot downloads." >&2
  echo "Run ./linux/deploy-stack.sh first." >&2
  exit 1
fi

printf '\nModel saved to: %s\n' "$DEST"

if [[ -d "$DEST" && -f "$DEST/config.json" ]]; then
  printf '\nTo start Cohere Transcribe in offline mode:\n'
  printf '  MODEL_PATH=%s LOCAL_FILES_ONLY=true ./linux/start-cohere-transcribe.sh\n' "$DEST"
else
  printf '\nTo start llama-server with this model:\n'
  printf '  MODEL_PATH=%s ./linux/start-llama-server.sh\n' "$DEST"
fi
