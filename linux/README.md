# Linux 啟動指南

完整的首次部署與日常啟動流程。

---

## 一、首次部署（只需執行一次）

### 1. 安裝系統依賴與 Python 環境

```bash
chmod +x linux/*.sh
./linux/deploy-stack.sh
```

預設會自動偵測 GPU backend：
- 有 CUDA → 建 CUDA 版 llama.cpp
- 有 Vulkan → 建 Vulkan 版
- 否則 → CPU

強制指定 backend：

```bash
LLAMA_BACKEND=cuda ./linux/deploy-stack.sh   # CUDA
LLAMA_BACKEND=cpu  ./linux/deploy-stack.sh   # 純 CPU
```

只安裝 Python 依賴，不重建 llama.cpp：

```bash
SKIP_LLAMA_BUILD=1 ./linux/deploy-stack.sh
```

---

### 2. 申請 Cohere Transcribe 模型存取權限

模型為 gated repo，需要先在 Hugging Face 申請：

1. 前往 [huggingface.co/CohereLabs/cohere-transcribe-03-2026](https://huggingface.co/CohereLabs/cohere-transcribe-03-2026)
2. 點擊 **"Request access"** 並同意使用條款
3. 等待批准（通常即時）

---

### 3. 登入 Hugging Face

取得你的 token：[huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)（Read 權限即可）

```bash
.venv/bin/python -c "import huggingface_hub; huggingface_hub.login()"
```

token 會快取在 `~/.cache/huggingface/token`，之後不需要重複登入。

---

### 4. 下載模型

```bash
HF_REPO=CohereLabs/cohere-transcribe-03-2026 HF_SNAPSHOT=1 ./linux/download-model.sh
```

模型預設儲存於：
```
models/CohereLabs--cohere-transcribe-03-2026/
```

若要指定其他路徑：

```bash
HF_REPO=CohereLabs/cohere-transcribe-03-2026 HF_SNAPSHOT=1 \
  MODEL_DIR=/your/custom/path \
  ./linux/download-model.sh
```

---

## 二、啟動服務

### 啟動 Cohere Transcribe（離線模式，推薦）

```bash
./linux/start-cohere-transcribe.sh
```

預設參數：

| 環境變數 | 預設值 | 說明 |
|---------|-------|------|
| `HOST` | `0.0.0.0` | 監聽位址 |
| `PORT` | `9000` | 監聽埠 |
| `LANGUAGE` | `en` | 預設語言 |
| `DEVICE` | `auto` | `auto` / `cuda:0` / `cpu` |
| `BATCH_SIZE` | `8` | 批次大小 |
| `MODEL_PATH` | `models/CohereLabs--cohere-transcribe-03-2026` | 模型目錄 |

覆蓋參數範例：

```bash
LANGUAGE=zh DEVICE=cuda:0 PORT=8080 ./linux/start-cohere-transcribe.sh
```

---

### 啟動 llama-server（可選）

本地 GGUF 模型：

```bash
MODEL_PATH=/path/to/model.gguf ./linux/start-llama-server.sh
```

從 Hugging Face 自動下載 GGUF：

```bash
HF_REPO=ggml-org/gemma-3-1b-it-GGUF ./linux/start-llama-server.sh
```

---

## 三、驗證服務

服務啟動後（預設 port 9000）：

```bash
# 健康檢查
curl http://localhost:9000/healthz

# 查看載入的模型
curl http://localhost:9000/v1/models

# 測試轉譯
curl http://localhost:9000/v1/audio/transcriptions \
  -F file=@your_audio.wav \
  -F language=en \
  -F response_format=json

# Admin 介面（瀏覽器開啟）
http://localhost:9000/admin
```

---

## 四、日常啟動（模型已下載後）

```bash
./linux/start-cohere-transcribe.sh
```

---

## 五、故障排除

### `GatedRepoError: 401` — 未登入
```bash
.venv/bin/python -c "import huggingface_hub; huggingface_hub.login()"
```

### `GatedRepoError: 403` — 未獲得存取權限
前往 [huggingface.co/CohereLabs/cohere-transcribe-03-2026](https://huggingface.co/CohereLabs/cohere-transcribe-03-2026) 申請存取。

### `RuntimeError: Local model directory not found`
先執行步驟 4 下載模型，或設定正確的 `MODEL_PATH`：
```bash
MODEL_PATH=/your/model/path ./linux/start-cohere-transcribe.sh
```

### `Python executable not found`
先執行步驟 1：
```bash
./linux/deploy-stack.sh
```
