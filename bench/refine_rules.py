#!/usr/bin/env python3
"""규칙 기반 한국어 후처리 — 사전 치환 + 공백 정리 + 종결부호 보정."""
import argparse, json, sys
from pathlib import Path


def refine(text, dictionary):
    t = " ".join(text.strip().split())
    if not t:
        return ""
    for k in sorted(dictionary, key=len, reverse=True):  # 긴 키 우선
        t = t.replace(k, dictionary[k])
    if t[-1] not in ".?!":
        t += "."
    return t


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--dict", default=str(Path(__file__).parent / "dict.json"))
    a = p.parse_args()
    d = json.loads(Path(a.dict).read_text())
    print(refine(sys.stdin.read(), d))
