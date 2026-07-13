# 녹음 안내 (Bible)

1. QuickTime Player → 파일 → 새 오디오 녹음 (내장 마이크면 충분 — 실사용 조건)
2. `script.md`의 s01부터 s28까지 **한 문장씩 따로** 녹음 (문장당 파일 1개)
3. 파일명: `s01.m4a`, `s02.m4a`, … → `bench/audio/raw/`에 저장
4. 완료 후: `bench/.venv/bin/python bench/add_recordings.py`
   (m4a→16kHz wav 변환 + manifest 등록까지 자동)

팁: 너무 또박또박 읽지 말고 평소 말투로 — 실사용 품질을 재는 게 목적.
