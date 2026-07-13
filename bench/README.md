# 받아써 한국어 품질 벤치

stock whisper large-v3-turbo vs 한국어 파인튜닝 3종 × 후처리 3단 비교.
스펙: ../docs/superpowers/specs/2026-07-13-badasseo-design.md 1부

## 실행 순서
1. `bench/setup.sh` — 툴체인·stock 모델
2. `bench/fetch_zeroth.py` — 공개 평가셋 30발화
3. `bench/convert_models.sh` — 파인튜닝 3종 GGML 변환
4. 본인 녹음 — `bench/RECORDING.md` 참고
5. `bench/run.py` — 전체 매트릭스 실행 → results/
6. `bench/score.py --report` — report.md 생성
7. `bench/blind.py` — 블라인드 비교 문서 생성 → 판정

audio/·results/·models/는 git-ignored. 결과는 report.md만 커밋.
