# llama.cpp + Cohere Transcribe Deployment Scripts

這個目錄現在提供 3 套分開的部署方式：

- Windows / PowerShell
- Linux / Bash
- Docker / Compose

每一套都放在不同子路徑，避免混用參數與執行方式。

## 子目錄

- `scripts/`
  Windows PowerShell 版本
- `linux/`
  Linux Bash 版本
- `docker/`
  Docker / Compose 版本
- `app/`
  共用的 Cohere Transcribe FastAPI 服務

## Windows 版本

這一套會建立兩個本機服務：

- `llama.cpp` 的 OpenAI-compatible LLM API
- `CohereLabs/cohere-transcribe-03-2026` 的語音轉文字 API

### 目錄

- `scripts/deploy-stack.ps1`
  安裝 Python 相依、建立虛擬環境、clone 並編譯 `llama.cpp`
- `scripts/start-llama-server.ps1`
  啟動 `llama-server`
- `scripts/start-cohere-transcribe.ps1`
  啟動 Cohere Transcribe HTTP 服務
- `app/cohere_server.py`
  FastAPI 服務，提供 `/healthz` 與 `/v1/audio/transcriptions`

### 先決條件

- Windows PowerShell 5.1+ 或 PowerShell 7+
- Python 3.11+
- Git
- CMake
- Visual Studio Build Tools 或 Visual Studio C++ toolchain
- 可選：CUDA Toolkit 或 Vulkan SDK

### 1. 安裝 / 建置

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\deploy-stack.ps1
```

預設會優先嘗試 GPU backend：

- 先找 CUDA
- 再找 Vulkan
- 最後 fallback 到 CPU

若要強制指定 backend：

```powershell
.\scripts\deploy-stack.ps1 -LlamaBackend cuda
```

若你只想更新 Python 環境，不重新建 `llama.cpp`：

```powershell
.\scripts\deploy-stack.ps1 -SkipLlamaBuild
```

### 2. 啟動 llama.cpp

使用本地 GGUF 模型：

```powershell
.\scripts\start-llama-server.ps1 -ModelPath D:\models\model.gguf -Port 8080 -GpuLayers 99
```

直接從 Hugging Face 載入相容 GGUF 模型：

```powershell
.\scripts\start-llama-server.ps1 -HfRepo ggml-org/gemma-3-1b-it-GGUF -Port 8080
```

啟動後預設可用端點：

- `http://localhost:8080`
- `http://localhost:8080/v1/chat/completions`

### 3. 啟動 Cohere Transcribe

先把模型預先下載到本地目錄：

```bash
HF_REPO=CohereLabs/cohere-transcribe-03-2026 HF_SNAPSHOT=1 ./linux/download-model.sh
```

Windows / PowerShell：

```powershell
.\scripts\start-cohere-transcribe.ps1 -Port 9000 -Language en -Device auto
```

Linux / Bash：

```bash
LANGUAGE=en DEVICE=auto ./linux/start-cohere-transcribe.sh
```

若要打開較高吞吐量的選項：

```powershell
.\scripts\start-cohere-transcribe.ps1 -Port 9000 -Language en -CompileEncoder -PipelineDetokenization
```

```bash
LANGUAGE=en DEVICE=auto COMPILE_ENCODER=true PIPELINE_DETOKENIZATION=true ./linux/start-cohere-transcribe.sh
```

啟動後可用端點：

- `http://localhost:9000/healthz`
- `http://localhost:9000/v1/audio/transcriptions`
- `http://localhost:9000/v1/models`
- `http://localhost:9000/admin`

### 4. 測試 Cohere Transcribe API

```powershell
curl.exe -X POST http://localhost:9000/v1/audio/transcriptions `
  -F "file=@D:\audio\sample.wav" `
  -F "language=en"
```

範例回應：

```json
{
  "text": "hello world",
  "language": "en",
  "model": "CohereLabs/cohere-transcribe-03-2026"
}
```

### 備註

- `cohere-transcribe` 需要明確指定 `language`，沒有自動語言辨識。
- `transformers 5.0` 與 `5.1` 與目前模型不相容，所以 `requirements.txt` 已排除。
- 所有本地 Python 環境統一使用專案根目錄的 `.enuv`。
- `llama.cpp` 需要 GGUF 模型；若用 `-HfRepo`，請選支援 `llama.cpp` 的 GGUF repository。
- `cohere-transcribe` 現在預設優先載入本地模型目錄 `models/CohereLabs--cohere-transcribe-03-2026`，並以 `local_files_only=true` 啟動。
- 若本地模型不存在，服務會在啟動時直接停止並提示先下載，不會自動去 Hugging Face 拉 gated repo。
- 若你真的要允許遠端回退，請明確設定 `ALLOW_REMOTE_FALLBACK=true` 並同時把 `LOCAL_FILES_ONLY=false`。
- `cohere-transcribe` 現在提供 OpenAI 風格的 `/v1/audio/transcriptions` 與 `/v1/models`，但仍是部分相容，不支援 timestamps、translation、streaming。
- `http://localhost:9000/admin` 提供內建管理介面，可查看設定、測試上傳與最近請求。

## Linux / Docker

Linux 用法請看 `linux/README.md`。

Docker 用法請看 `docker/README.md`。
