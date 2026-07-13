#!/usr/bin/env python3
"""받아써 벤치 채점기 — CER·띄어쓰기 분리·지연 집계, report.md 생성."""
import argparse, json, unicodedata
from collections import defaultdict
from pathlib import Path


def normalize(s):
    s = unicodedata.normalize("NFC", s).strip()
    return " ".join(s.split())


def levenshtein(a, b):
    if len(a) < len(b):
        a, b = b, a
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def cer(ref, hyp):
    ref, hyp = normalize(ref), normalize(hyp)
    if not ref:
        return 1.0
    return levenshtein(ref, hyp) / len(ref)


def cer_content(ref, hyp):
    return cer(normalize(ref).replace(" ", ""), normalize(hyp).replace(" ", ""))


def spacing_gap(ref, hyp):
    return max(0.0, cer(ref, hyp) - cer_content(ref, hyp))


def build_report(results_dir, manifest_path, out_path):
    """results/*.jsonl 집계 → 모델×후처리 표. 스키마는 run.py 참고:
    {"file","model","post","text","transcribe_s","post_s"}"""
    refs = {e["file"]: e["text"] for e in json.loads(Path(manifest_path).read_text())}
    rows = defaultdict(lambda: {"cer": [], "gap": [], "lat": [], "n": 0, "audio_s": []})
    for f in sorted(Path(results_dir).glob("*.jsonl")):
        for line in f.read_text().splitlines():
            r = json.loads(line)
            ref = refs.get(r["file"])
            if ref is None:
                continue
            key = (r["model"], r["post"])
            rows[key]["cer"].append(cer_content(ref, r["text"]))
            rows[key]["gap"].append(spacing_gap(ref, r["text"]))
            rows[key]["lat"].append(r["transcribe_s"] + r["post_s"])
            rows[key]["audio_s"].append(r.get("audio_s", 0))
            rows[key]["n"] += 1
    mean = lambda xs: sum(xs) / len(xs) if xs else 0.0
    lines = [
        "# 받아써 한국어 품질 벤치 결과", "",
        "판정 기준(스펙): 진행 = ①블라인드 체감 우위 ②CER 개선 ③지연 <1초/발화10초 모두 충족. 킬 = 전 조합 무차별 or 지연 초과.", "",
        "| 모델 | 후처리 | cer_content | spacing_gap | 평균지연(s) | 지연/음성10s | n |",
        "|---|---|--:|--:|--:|--:|--:|",
    ]
    for (model, post), v in sorted(rows.items()):
        per10 = mean(v["lat"]) / (mean(v["audio_s"]) / 10) if mean(v["audio_s"]) > 0 else 0
        lines.append(
            f"| {model} | {post} | {mean(v['cer']):.4f} | {mean(v['gap']):.4f} "
            f"| {mean(v['lat']):.2f} | {per10:.2f} | {v['n']} |")
    Path(out_path).write_text("\n".join(lines) + "\n")
    print(f"wrote {out_path} ({len(rows)} rows)")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--results", default="results")
    p.add_argument("--manifest", default="audio/manifest.json")
    p.add_argument("--report", default="report.md")
    a = p.parse_args()
    build_report(a.results, a.manifest, a.report)
