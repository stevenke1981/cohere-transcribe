# Linux Scripts

這個子目錄提供 Linux / Bash 版本的部署與啟動腳本。

## 檔案

- `deploy-stack.sh`
- `start-llama-server.sh`
- `start-cohere-transcribe.sh`

## 先決條件

- Ubuntu / Debian / RHEL / 其他常見 Linux 發行版
- `python3`
- `git`
- `cmake`
- `build-essential` 或等效 C/C++ 編譯工具
- 可選：CUDA Toolkit（若要建 CUDA 版 `llama.cpp`）

## 用法

```bash
chmod +x linux/*.sh
./linux/deploy-stack.sh
```

預設會優先嘗試 GPU backend：

- 先找 CUDA
- 再找 Vulkan
- 最後 fallback 到 CPU

強制指定 CUDA：

```bash
LLAMA_BACKEND=cuda ./linux/deploy-stack.sh
```

只安裝 Python 依賴，不重建 `llama.cpp`：

```bash
SKIP_LLAMA_BUILD=1 ./linux/deploy-stack.sh
```

啟動 `llama-server`：

```bash
MODEL_PATH=/models/model.gguf ./linux/start-llama-server.sh
```

或：

```bash
HF_REPO=ggml-org/gemma-3-1b-it-GGUF ./linux/start-llama-server.sh
```

啟動 `cohere-transcribe`：

先下載完整模型快照：

```bash
HF_REPO=CohereLabs/cohere-transcribe-03-2026 HF_SNAPSHOT=1 ./linux/download-model.sh
```

預設會優先使用 `models/CohereLabs--cohere-transcribe-03-2026`，並以離線模式載入：

```bash
LANGUAGE=en DEVICE=auto ./linux/start-cohere-transcribe.sh
```

若確實需要允許 Hugging Face 遠端回退：

```bash
LANGUAGE=en DEVICE=auto LOCAL_FILES_ONLY=false ALLOW_REMOTE_FALLBACK=true ./linux/start-cohere-transcribe.sh
```
