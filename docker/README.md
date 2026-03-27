# Docker Deployment

這個子目錄提供 Docker 版部署，將兩個服務拆成不同 container：

- `llama-cpp`
- `cohere-transcribe`

## 檔案

- `Dockerfile.llama`
- `Dockerfile.cohere`
- `compose.yaml`
- `.env.example`

## 使用方式

先準備模型目錄，例如：

```text
../models/model.gguf
```

建立環境檔：

```bash
cd docker
cp .env.example .env
```

啟動：

```bash
docker compose up --build
```

背景執行：

```bash
docker compose up --build -d
```

停止：

```bash
docker compose down
```

## 預設端點

- `http://localhost:8080/v1/chat/completions`
- `http://localhost:9000/v1/audio/transcriptions`

## 備註

- 這份 Docker 版本已改成 GPU-first：映像會建 CUDA 版 `llama.cpp`，container 取得 GPU 時會自動帶 `-ngl 999`，否則 fallback CPU。
- `cohere-transcribe` container 內的 Python 環境使用專案級 `/app/.enuv`。
- 若要讓 Docker 真的看到 NVIDIA GPU，仍需要正確安裝 NVIDIA Container Toolkit 或等效 runtime。
- `cohere-transcribe` 第一次啟動會下載 Hugging Face 模型，請確保網路可用。
