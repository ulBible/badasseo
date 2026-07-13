#!/bin/bash
# HF 한국어 파인튜닝 whisper 3종 → whisper.cpp GGML 변환
set -uo pipefail   # -e 없음: 한 모델 실패해도 다음 모델 진행
cd "$(dirname "$0")/.."
PY=bench/.venv/bin/python
PIP=bench/.venv/bin/pip
HF=bench/.venv/bin/hf

$PIP install -q torch transformers  # 변환에만 필요 (~2GB, 최초 1회)

# 변환 스크립트와 mel filter 에셋
[ -d /tmp/whisper.cpp ] || git clone --depth 1 https://github.com/ggml-org/whisper.cpp /tmp/whisper.cpp
[ -d /tmp/openai-whisper ] || git clone --depth 1 https://github.com/openai/whisper /tmp/openai-whisper

# 다운로드 대상: 변환에 필요한 root-level 파일만, 명시적 파일명으로 지정.
# (주의: `hf` 1.8.0에서 --include를 반복 지정하면 마지막 값만 적용되는 버그가 있어
#  대신 explicit FILENAMES positional을 사용한다. 일부 repo는 checkpoint-*/, runs/ 등에
#  optimizer state·tfevents까지 올라와 있어 이 필터 없이 받으면 수십GB로 불어난다.
#  generation_config.json처럼 repo에 없는 파일은 조용히 건너뛰어지고 exit 0.)
NEEDED_FILES=(
  config.json vocab.json merges.txt added_tokens.json normalizer.json
  preprocessor_config.json special_tokens_map.json tokenizer_config.json
  model.safetensors generation_config.json
)

convert() {  # $1=HF repo  $2=출력명
  local repo="$1" out="$2" dir="/tmp/hf-$(basename "$1")"
  echo "== $repo =="
  if [ -f "models/$out" ]; then echo "이미 있음, 건너뜀"; return 0; fi
  $HF download "$repo" "${NEEDED_FILES[@]}" --local-dir "$dir" || { echo "FAIL(download): $repo"; return 1; }
  $PY /tmp/whisper.cpp/models/convert-h5-to-ggml.py "$dir" /tmp/openai-whisper models \
    || { echo "FAIL(convert): $repo"; return 1; }
  mv models/ggml-model.bin "models/$out"
  echo "OK: models/$out"
}

convert ghost613/whisper-large-v3-turbo-korean            ggml-ghost613.bin
convert o0dimplz0o/Whisper-Large-v3-turbo-STT-Zeroth-KO-v2 ggml-o0dimplz0o.bin
convert imTak/whisper_large_v3_turbo_korean_Develop        ggml-imtak.bin

echo "== 결과 =="
ls -lh models/ggml-*.bin
