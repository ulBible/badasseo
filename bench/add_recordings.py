#!/usr/bin/env python3
"""bench/audio/raw/sNN.m4a → 16kHz wav 変換 + script.md 대본을 정답으로 manifest 등록."""
import json, re, subprocess
from pathlib import Path

ROOT = Path(__file__).parent
RAW, OWN = ROOT / "audio" / "raw", ROOT / "audio" / "own"


def script_texts():
    txt = (ROOT / "script.md").read_text()
    return dict(re.findall(r"- (s\d+): (.+)", txt))


def main():
    OWN.mkdir(parents=True, exist_ok=True)
    texts = script_texts()
    mpath = ROOT / "audio" / "manifest.json"
    manifest = [e for e in json.loads(mpath.read_text()) if e.get("set") != "own"]
    n = 0
    for m4a in sorted(RAW.glob("s*.m4a")):
        sid = m4a.stem
        if sid not in texts:
            print(f"skip {m4a.name}: 대본에 없는 id"); continue
        wav = OWN / f"{sid}.wav"
        subprocess.run(["ffmpeg", "-y", "-i", str(m4a), "-ar", "16000", "-ac", "1",
                        str(wav)], capture_output=True, check=True)
        dur = float(subprocess.run(
            ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
             "-of", "csv=p=0", str(wav)], capture_output=True, text=True).stdout)
        manifest.append({"file": f"own/{sid}.wav", "text": texts[sid],
                         "set": "own", "audio_s": round(dur, 2)})
        n += 1
    mpath.write_text(json.dumps(manifest, ensure_ascii=False, indent=1))
    print(f"registered {n} recordings ({len(manifest)} total entries)")


if __name__ == "__main__":
    main()
