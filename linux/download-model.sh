#!/usr/bin/env bash
set -euo pipefail

# Downloads a GGUF model from Hugging Face.
#
# Usage:
#   HF_REPO=ggml-org/gemma-3-1b-it-GGUF ./linux/download-model.sh
#   HF_REPO=ggml-org/gemma-3-1b-it-GGUF HF_FILE=gemma-3-1b-it-Q4_K_M.gguf ./linux/download-model.sh
#
# Environment variables:
#   HF_REPO        Hugging Face repo (required, e.g. ggml-org/gemma-3-1b-it-GGUF)
#   HF_FILE        Filename inside the repo (default: auto-select first *.gguf)
#   MODEL_DIR      Destination directory (default: <repo-root>/models)
#   HF_TOKEN       Hugging Face token for gated models (optional)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="${ROOT_DIR}/.venv/bin/python"
MODEL_DIR="${MODEL_DIR:-$ROOT_DIR/models}"
HF_REPO="${HF_REPO:-}"
HF_FILE="${HF_FILE:-}"

if [[ -z "$HF_REPO" ]]; then
  echo "Usage: HF_REPO=owner/repo-name $0" >&2
  echo "       HF_REPO=owner/repo-name HF_FILE=model.gguf $0" >&2
  exit 1
fi

mkdir -p "$MODEL_DIR"

# ------------------------------------------------------------------
# Prefer huggingface-cli from the project venv; fall back to curl/wget
# ------------------------------------------------------------------
download_via_hf_cli() {
  local python_bin="$1"
  local repo="$2"
  local file="$3"

  if [[ -n "${HF_TOKEN:-}" ]]; then
    "$python_bin" -c "
import huggingface_hub, os
huggingface_hub.login(token=os.environ['HF_TOKEN'], add_to_git_credential=False)
" 2>/dev/null || true
  fi

  if [[ -n "$file" ]]; then
    "$python_bin" -c "
import huggingface_hub, sys
path = huggingface_hub.hf_hub_download(
    repo_id='$repo',
    filename='$file',
    local_dir='$MODEL_DIR',
    local_dir_use_symlinks=False,
)
print(path)
"
  else
    # Auto-select: pick the first .gguf file in the repo
    "$python_bin" -c "
import huggingface_hub, sys
api = huggingface_hub.HfApi()
files = [f.rfilename for f in api.list_repo_files('$repo') if f.rfilename.endswith('.gguf')]
if not files:
    print('No .gguf files found in $repo', file=sys.stderr)
    sys.exit(1)
chosen = sorted(files)[0]
print(f'Auto-selected: {chosen}', file=sys.stderr)
path = huggingface_hub.hf_hub_download(
    repo_id='$repo',
    filename=chosen,
    local_dir='$MODEL_DIR',
    local_dir_use_symlinks=False,
)
print(path)
"
  fi
}

download_via_curl() {
  local repo="$1"
  local file="$2"
  local dest="$MODEL_DIR/$file"
  local url="https://huggingface.co/${repo}/resolve/main/${file}"
  local curl_args=(-L --progress-bar -o "$dest")
  if [[ -n "${HF_TOKEN:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${HF_TOKEN}")
  fi
  echo "Downloading $url -> $dest" >&2
  curl "${curl_args[@]}" "$url"
  printf '%s\n' "$dest"
}

if [[ -x "$VENV_PYTHON" ]]; then
  DEST="$(download_via_hf_cli "$VENV_PYTHON" "$HF_REPO" "$HF_FILE")"
elif command -v curl >/dev/null 2>&1; then
  if [[ -z "$HF_FILE" ]]; then
    echo "HF_FILE must be set when huggingface_hub venv is unavailable." >&2
    echo "Run ./linux/deploy-stack.sh first, or set HF_FILE explicitly." >&2
    exit 1
  fi
  DEST="$(download_via_curl "$HF_REPO" "$HF_FILE")"
else
  echo "Neither the project venv nor curl is available. Run ./linux/deploy-stack.sh first." >&2
  exit 1
fi

printf '\nModel saved to: %s\n' "$DEST"
printf '\nTo start llama-server with this model:\n'
printf '  MODEL_PATH=%s ./linux/start-llama-server.sh\n' "$DEST"
