#!/usr/bin/env python3
"""kresnik/zeroth_korean test split에서 30발화를 wav+정답으로 추출."""
import io, json
from pathlib import Path

import numpy as np
import soundfile as sf
from huggingface_hub import hf_hub_download

BASE = Path(__file__).parent / "audio"
N = 30


def load_manifest():
    p = BASE / "manifest.json"
    return json.loads(p.read_text()) if p.exists() else []


def main():
    import pyarrow.parquet as pq  # venv에 pyarrow 필요 (아래 Step 2에서 설치)
    fp = hf_hub_download("kresnik/zeroth_korean", "data/test-00000-of-00001.parquet",
                         repo_type="dataset")
    table = pq.read_table(fp).to_pylist()
    (BASE / "zeroth").mkdir(parents=True, exist_ok=True)
    manifest = [e for e in load_manifest() if e.get("set") != "zeroth"]
    for i, row in enumerate(table[:N]):
        audio = row["audio"]
        # HF datasets parquet: {"bytes": wav바이트} 또는 {"array","sampling_rate"}
        if audio.get("bytes"):
            data, sr = sf.read(io.BytesIO(audio["bytes"]))
        else:
            data, sr = np.array(audio["array"]), audio["sampling_rate"]
        out = BASE / "zeroth" / f"z{i:03d}.wav"
        sf.write(out, data, sr)
        manifest.append({"file": f"zeroth/{out.name}", "text": row["text"].strip(),
                         "set": "zeroth", "audio_s": round(len(data) / sr, 2)})
    (BASE / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1))
    print(f"wrote {N} wavs + manifest ({len(manifest)} entries)")


if __name__ == "__main__":
    main()
