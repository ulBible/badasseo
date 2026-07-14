#!/usr/bin/env python3
"""전체 매트릭스 실행: 모델 × 음성 × 후처리 → results/*.jsonl"""
import json, os, subprocess, time
from pathlib import Path

# whisper-cli/llama-cli는 /opt/homebrew/bin에 있으나 컨트롤러 기본 PATH에는 없음.
# 여기서 PATH에 추가해두면 이 프로세스의 subprocess.run(...)뿐 아니라, 같은 프로세스
# 안에서 호출되는 refine_llm.py의 llama-cli 호출도 (환경을 상속하므로) 동작한다.
os.environ["PATH"] = "/opt/homebrew/bin:" + os.environ.get("PATH", "")

from refine_rules import refine
from refine_llm import refine_llm

ROOT = Path(__file__).parent
MODELS = {  # 존재하는 것만 실행
    "stock-turbo": "ggml-large-v3-turbo.bin",
    "ghost613": "ggml-ghost613.bin",
    "o0dimplz0o": "ggml-o0dimplz0o.bin",
    "imtak": "ggml-imtak.bin",
}
DICT = json.loads((ROOT / "dict.json").read_text())


def transcribe(model_path, wav):
    t0 = time.monotonic()
    r = subprocess.run(
        ["whisper-cli", "-m", str(model_path), "-f", str(wav), "-l", "ko", "-nt"],
        capture_output=True, timeout=300)
    # whisper-cli가 간혹 불완전한 UTF-8 바이트를 내보냄 (실측: 0x85) — 크래시 대신 대체
    return r.stdout.decode("utf-8", errors="replace").strip(), time.monotonic() - t0


def main():
    manifest = json.loads((ROOT / "audio" / "manifest.json").read_text())
    (ROOT / "results").mkdir(exist_ok=True)
    for name, fn in MODELS.items():
        mp = ROOT.parent / "models" / fn
        if not mp.exists():
            print(f"skip {name} (모델 없음)")
            continue
        out = ROOT / "results" / f"{name}.jsonl"
        with out.open("w") as f:
            for e in manifest:
                wav = ROOT / "audio" / e["file"]
                raw, t_s = transcribe(mp, wav)
                variants = [("none", raw, 0.0)]
                t0 = time.monotonic()
                variants.append(("rules", refine(raw, DICT), time.monotonic() - t0))
                llm_text, llm_s = refine_llm(raw)
                variants.append(("llm", llm_text, llm_s))
                for post, text, p_s in variants:
                    f.write(json.dumps({
                        "file": e["file"], "model": name, "post": post, "text": text,
                        "transcribe_s": round(t_s, 2), "post_s": round(p_s, 2),
                        "audio_s": e.get("audio_s", 0)}, ensure_ascii=False) + "\n")
                print(f"{name} {e['file']} {t_s:.1f}s")
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
