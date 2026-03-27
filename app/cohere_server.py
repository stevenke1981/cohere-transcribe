from __future__ import annotations

import os
from collections import deque
from dataclasses import dataclass
from datetime import UTC, datetime
from functools import lru_cache
from pathlib import Path
from tempfile import NamedTemporaryFile
from threading import Lock
from typing import Any

import torch
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import HTMLResponse, JSONResponse, PlainTextResponse
from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor

from app.admin_ui import render_admin_page


def _env_flag(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


RECENT_REQUESTS: deque[dict[str, Any]] = deque(maxlen=20)
RECENT_REQUESTS_LOCK = Lock()


@dataclass(frozen=True)
class Settings:
    model_id: str
    device: str
    default_language: str
    batch_size: int
    compile_encoder: bool
    pipeline_detokenization: bool

    @staticmethod
    def load() -> "Settings":
        requested_device = os.getenv("COHERE_DEVICE", "auto").strip().lower()
        if requested_device == "auto":
            device = "cuda:0" if torch.cuda.is_available() else "cpu"
        else:
            device = requested_device

        return Settings(
            model_id=os.getenv(
                "COHERE_MODEL_ID", "CohereLabs/cohere-transcribe-03-2026"
            ).strip(),
            device=device,
            default_language=os.getenv("COHERE_DEFAULT_LANGUAGE", "en").strip(),
            batch_size=int(os.getenv("COHERE_BATCH_SIZE", "8")),
            compile_encoder=_env_flag("COHERE_COMPILE", default=False),
            pipeline_detokenization=_env_flag(
                "COHERE_PIPELINE_DETOKENIZATION", default=False
            ),
        )


def get_settings() -> Settings:
    return Settings.load()


@dataclass
class CohereRuntime:
    settings: Settings
    processor: AutoProcessor
    model: AutoModelForSpeechSeq2Seq

    @classmethod
    def create(cls) -> "CohereRuntime":
        settings = Settings.load()
        processor = AutoProcessor.from_pretrained(
            settings.model_id, trust_remote_code=True
        )
        model = AutoModelForSpeechSeq2Seq.from_pretrained(
            settings.model_id, trust_remote_code=True
        ).to(settings.device)
        model.eval()
        return cls(settings=settings, processor=processor, model=model)

    def transcribe_file(
        self,
        audio_path: Path,
        language: str,
        punctuation: bool,
    ) -> str:
        results = self.model.transcribe(
            processor=self.processor,
            audio_files=[str(audio_path)],
            language=language,
            punctuation=punctuation,
            batch_size=self.settings.batch_size,
            compile=self.settings.compile_encoder,
            pipeline_detokenization=self.settings.pipeline_detokenization,
        )
        if not results:
            raise RuntimeError("Empty transcription result.")
        return results[0]


@lru_cache(maxsize=1)
def get_runtime() -> CohereRuntime:
    return CohereRuntime.create()


def runtime_is_loaded() -> bool:
    return get_runtime.cache_info().currsize > 0


def record_request(
    *,
    filename: str,
    language: str,
    response_format: str,
    text: str,
) -> None:
    item = {
        "filename": filename,
        "language": language,
        "response_format": response_format,
        "preview": text[:240],
        "created_at": datetime.now(UTC).isoformat(timespec="seconds"),
    }
    with RECENT_REQUESTS_LOCK:
        RECENT_REQUESTS.appendleft(item)


def recent_requests() -> list[dict[str, Any]]:
    with RECENT_REQUESTS_LOCK:
        return list(RECENT_REQUESTS)


app = FastAPI(
    title="Cohere Transcribe Server",
    version="0.1.0",
    description="Minimal HTTP server for CohereLabs/cohere-transcribe-03-2026.",
)


@app.get("/healthz")
def healthz() -> dict[str, object]:
    settings = get_settings()
    return {
        "status": "ok",
        "model_id": settings.model_id,
        "device": settings.device,
        "default_language": settings.default_language,
    }


@app.get("/v1/models")
def list_models() -> dict[str, object]:
    settings = get_settings()
    return {
        "object": "list",
        "data": [
            {
                "id": settings.model_id,
                "object": "model",
                "created": 0,
                "owned_by": "local",
            }
        ],
    }


@app.get("/admin", response_class=HTMLResponse)
def admin_page() -> str:
    return render_admin_page()


@app.get("/admin/api/status")
def admin_status() -> dict[str, object]:
    settings = get_settings()
    return {
        "status": "ok",
        "model_id": settings.model_id,
        "device": settings.device,
        "default_language": settings.default_language,
        "batch_size": settings.batch_size,
        "compile_encoder": settings.compile_encoder,
        "pipeline_detokenization": settings.pipeline_detokenization,
        "runtime_loaded": runtime_is_loaded(),
    }


@app.get("/admin/api/recent")
def admin_recent() -> dict[str, object]:
    return {"items": recent_requests()}


@app.post("/v1/audio/transcriptions", response_model=None)
async def create_transcription(
    file: UploadFile = File(...),
    model: str | None = Form(default=None),
    language: str | None = Form(default=None),
    punctuation: bool = Form(default=True),
    prompt: str | None = Form(default=None),
    response_format: str | None = Form(default="json"),
    temperature: float | None = Form(default=None),
    timestamp_granularities: list[str] | None = Form(default=None),
) -> JSONResponse | PlainTextResponse | dict[str, object]:
    runtime = get_runtime()

    if model and model != runtime.settings.model_id:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Loaded model is {runtime.settings.model_id}, "
                f"but request asked for {model}."
            ),
        )

    target_language = (language or runtime.settings.default_language).strip()
    if not target_language:
        raise HTTPException(status_code=400, detail="language is required.")

    normalized_response_format = (response_format or "json").strip().lower()
    if normalized_response_format not in {"json", "text", "verbose_json"}:
        raise HTTPException(
            status_code=400,
            detail="Unsupported response_format. Use json, text, or verbose_json.",
        )

    suffix = Path(file.filename or "upload.wav").suffix or ".wav"
    payload = await file.read()
    if not payload:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    temp_path: str | None = None
    try:
        with NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            temp_file.write(payload)
            temp_path = temp_file.name

        text = runtime.transcribe_file(
            audio_path=Path(temp_path),
            language=target_language,
            punctuation=punctuation,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Transcription failed: {exc}",
        ) from exc
    finally:
        if temp_path:
            Path(temp_path).unlink(missing_ok=True)

    record_request(
        filename=file.filename or "upload.wav",
        language=target_language,
        response_format=normalized_response_format,
        text=text,
    )

    base_response: dict[str, object] = {
        "text": text,
        "language": target_language,
        "model": runtime.settings.model_id,
        "response_format": normalized_response_format,
    }

    if prompt:
        base_response["prompt_accepted"] = True

    if temperature is not None:
        base_response["temperature_accepted"] = temperature

    if timestamp_granularities:
        base_response["timestamp_granularities_accepted"] = timestamp_granularities

    if normalized_response_format == "text":
        return PlainTextResponse(text)

    if normalized_response_format == "verbose_json":
        base_response["segments"] = []
        base_response["words"] = []

    return JSONResponse(base_response)
