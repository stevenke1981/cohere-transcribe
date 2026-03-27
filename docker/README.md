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
- `cohere-transcribe` 現在預設讀取 `/models/CohereLabs--cohere-transcribe-03-2026`，請先在宿主機 `../models/` 準備好完整模型快照。
- 建議先執行 `HF_REPO=CohereLabs/cohere-transcribe-03-2026 HF_SNAPSHOT=1 ./linux/download-model.sh`，再 `docker compose up`。
- 若本地模型不存在，container 會在啟動時直接失敗並提示先下載；若要改成允許遠端回退，請設定 `COHERE_LOCAL_FILES_ONLY=false` 與 `COHERE_ALLOW_REMOTE_FALLBACK=true`。
