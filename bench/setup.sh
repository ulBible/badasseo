#!/bin/bash
# 벤치 툴체인 셋업 — 여러 번 실행해도 안전(idempotent)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== brew 패키지 =="
brew list whisper-cpp &>/dev/null || brew install whisper-cpp
brew list llama.cpp &>/dev/null || brew install llama.cpp
brew list ffmpeg &>/dev/null || brew install ffmpeg

echo "== python venv =="
[ -d bench/.venv ] || python3 -m venv bench/.venv
bench/.venv/bin/pip install -q --upgrade pip
bench/.venv/bin/pip install -q "huggingface_hub[cli]" soundfile numpy

echo "== 디렉토리 =="
mkdir -p bench/audio/own bench/audio/zeroth bench/results models

echo "== stock 모델 (1.6GB, 이어받기 지원) =="
if [ ! -f models/ggml-large-v3-turbo.bin ]; then
  bench/.venv/bin/hf download ggerganov/whisper.cpp ggml-large-v3-turbo.bin \
    --local-dir models/
fi

echo "OK — 셋업 완료"
