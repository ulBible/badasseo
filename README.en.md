<p align="right">
  <a href="README.md">한국어로 보기</a>
</p>

<p align="center">
  <img src="docs/icon-256.png" width="128" alt="Badasseo app icon">
</p>

<h1 align="center">받아써 (Badasseo)</h1>

<p align="center">
  Say it, and it's written. Speak instead of type on your Mac — entirely on your Mac.
</p>

Badasseo is a macOS menu-bar app for Korean voice input. Hold a shortcut and speak;
a local Whisper model transcribes what you said and inserts it right at your cursor.
No server, no account, no subscription.

## What's different

- **It just works after install** — the language is fixed to Korean. Auto language
  detection is prone to hallucinating Korean speech into unrelated English text (a
  problem we ran into firsthand); Badasseo removes that failure path entirely by design.
- **Privacy** — everything runs locally via whisper.cpp + Metal. No network calls for
  transcription, no accounts, no subscriptions. See [PRIVACY.md](PRIVACY.md) for details.
- **Built-in developer dictionary** — corrects the phonetic Korean transliterations
  developers commonly say back into their original English terms, e.g. "깃허브" → "GitHub",
  "풀 리퀘스트" → "PR". Fully editable in Settings.
- **Works fully with zero permissions** — the Accessibility permission is opt-in. Without
  it, ⌥Space + manual ⌘V gives you the complete feature set.

## Usage

1. Hold the right ⌘ key (or another hold key you pick in Settings) and speak.
2. Release it — the transcribed text is inserted right at your cursor.

If you'd rather not grant Accessibility access, use ⌥Space mode instead — no permission
needed; the transcription lands on your clipboard and you paste it yourself with ⌘V.

## Install

Packaged releases (DMG, Mac App Store) are still in progress. For now, build from source:

```bash
git clone https://github.com/ulBible/badasseo.git
cd badasseo
./scripts/bundle.sh release
open build/Badasseo.app
```

**Requirements**: Apple Silicon Mac, macOS 14+. On first launch it downloads the Korean
recognition model (Whisper large-v3-turbo, ~1.6GB) once.

## Why stock Whisper

We benchmarked three fine-tuned Korean models and didn't adopt any of them. In a blind
comparison (source hidden and shuffled, 26 valid samples), **stock large-v3-turbo was
preferred 62% of the time** — the fine-tuned model with the best CER score actually made
more content errors on real speech, an overfit to its own training distribution rather
than a real quality edge. Full methodology and numbers are in [bench/report.md](bench/report.md).

## Permissions

| Permission | Required? | Used for |
|---|---|---|
| None | No | Full functionality via ⌥Space + manual ⌘V |
| Microphone | Only while recording | Only while the shortcut is held; discarded immediately after processing |
| Accessibility | Opt-in | Detecting the right-⌘ hold and auto-inserting text at your cursor (synthesized ⌘V) |

## Support

Badasseo is free and open source (MIT). If it's useful to you, consider supporting it.

[Sponsor Badasseo ❤️](https://github.com/sponsors/ulBible)

## License

[MIT](LICENSE)

---

<p align="center">
  Made by <strong>Chakchak Works</strong> · by <a href="https://github.com/ulBible">ulBible</a>
</p>
