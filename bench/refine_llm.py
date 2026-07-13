#!/usr/bin/env python3
"""소형 로컬 LLM(Qwen) 한국어 교정 — 띄어쓰기·문장부호만 고치고 내용은 보존."""
import subprocess, sys, time
from pathlib import Path

MODEL = Path(__file__).parent.parent / "models" / "qwen3-1.7b-q4.gguf"
SYSTEM_PROMPT = (
    "당신은 한국어 음성 전사 교정기입니다. 사용자가 문장을 주면 띄어쓰기와 문장부호만 "
    "교정한 결과 문장 하나만 출력하세요. 설명, 인사, 마크다운을 절대 포함하지 마세요."
)
TIMEOUT_S = 10  # 벤치는 실제 소요를 측정하는 게 목적 — 넉넉히 두고 시간을 기록


def _extract_candidate(stdout):
    """llama-cli의 REPL 배너/에코/타이밍 라인을 걷어내고 생성된 응답만 뽑아낸다."""
    # 타이밍 라인("[ Prompt: ... t/s ]") 앞부분만 취급
    before_metrics = stdout.split("\n[ Prompt:")[0]
    if "</think>" in before_metrics:
        block = before_metrics.rsplit("</think>", 1)[1]
    else:
        parts = before_metrics.split("\n> ", 1)
        block = parts[1] if len(parts) > 1 else before_metrics
    lines = [ln.strip() for ln in block.splitlines() if ln.strip()]
    return " ".join(lines)


def refine_llm(text):
    t0 = time.monotonic()
    if not MODEL.exists() or not text.strip():
        return text, 0.0
    try:
        r = subprocess.run(
            ["llama-cli", "-m", str(MODEL), "--no-display-prompt", "-st",
             "--reasoning-budget", "0", "--temp", "0", "-n", "128",
             "-sys", SYSTEM_PROMPT, "-p", text.strip()],
            capture_output=True, text=True, timeout=TIMEOUT_S,
            stdin=subprocess.DEVNULL)
        cand = _extract_candidate(r.stdout)
        # 비정상(빈 출력, 원문 대비 과도한 길이 변화 ±50%) → 원문 폴백
        if not cand or not (0.5 <= len(cand) / max(len(text), 1) <= 1.5):
            cand = text
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        cand = text
    return cand, time.monotonic() - t0


if __name__ == "__main__":
    fixed, secs = refine_llm(sys.stdin.read())
    print(fixed)
    print(f"{secs:.2f}", file=sys.stderr)
