#!/usr/bin/env python3
"""본인 녹음(set=own)에 대한 익명 비교표 생성 — 라벨 순서는 파일별로 셔플."""
import json, random
from pathlib import Path

ROOT = Path(__file__).parent
POST = "rules"  # 비교 기준 후처리 단계 (필요시 바꿔 재생성)


def main():
    manifest = json.loads((ROOT / "audio" / "manifest.json").read_text())
    own = [e for e in manifest if e["set"] == "own"]
    by_model = {}
    for f in (ROOT / "results").glob("*.jsonl"):
        for line in f.read_text().splitlines():
            r = json.loads(line)
            if r["post"] == POST:
                by_model.setdefault(r["file"], {})[r["model"]] = r["text"]
    rng = random.Random(20260713)  # 재현 가능 셔플
    lines = ["# 블라인드 비교 (본인 녹음 · 후처리=" + POST + ")",
             "", "각 문장에서 가장 자연스러운 출력의 라벨에 ✅ 표시하세요.", ""]
    key = {}
    for e in own:
        outs = by_model.get(e["file"])
        if not outs:
            continue
        models = sorted(outs)
        rng.shuffle(models)
        labels = "ABCD"[: len(models)]
        key[e["file"]] = dict(zip(labels, models))
        lines += [f"## {e['file']}", f"정답: {e['text']}", ""]
        lines += [f"- [ ] **{l}**: {outs[m]}" for l, m in zip(labels, models)]
        lines.append("")
    (ROOT / "blind.md").write_text("\n".join(lines))
    (ROOT / "blind_key.json").write_text(json.dumps(key, indent=1))
    print(f"wrote blind.md ({len(key)} items) + blind_key.json (판정 전 열지 말 것)")


if __name__ == "__main__":
    main()
