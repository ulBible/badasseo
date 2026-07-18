<p align="right">
  <a href="README.en.md">Read in English</a>
</p>

<p align="center">
  <img src="docs/icon-256.png" width="128" alt="받아써 앱 아이콘">
</p>

<h1 align="center">받아써 (Badasseo)</h1>

<p align="center">
  말하면, 받아써. 맥에서 키보드 대신 말로 — 전 과정이 내 맥 안에서.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Apple%20Silicon-arm64-orange" alt="Apple Silicon">
  <a href="https://github.com/sponsors/ulBible"><img src="https://img.shields.io/badge/Sponsor-%E2%9D%A4-ff69b4" alt="Sponsor"></a>
</p>

*A **Chakchak Works** app — small tools that snap right in.*

<p align="center">
  <img src="docs/images/onboarding.png" width="560" alt="받아써 온보딩 — 말하면, 받아써. 목소리에서 텍스트까지 전 과정이 맥 안에서">
</p>

받아써는 macOS 메뉴바에 상주하는 **한국어 퍼스트** 음성입력 앱입니다. 단축키를 누른 채
말하면 로컬 Whisper가 전사해 커서 위치에 그대로 입력합니다. 서버도, 계정도, 구독도
없습니다. 한국어에 최적화됐지만 한국어 전용은 아니에요 — 영어가 섞인 문장도, 통째로
영어 문장도 그대로 받아써집니다.

## 뭐가 다른가

- **설치하면 그냥 됨** — 언어를 한국어로 고정했습니다. 자동 언어 감지 방식은
  한국어 발화를 엉뚱한 영어로 잘못 옮기는 환각 문제가 흔한데, 받아써는 애초에
  그 실패 경로 자체가 없습니다. 고정은 오역을 막는 안전장치일 뿐이에요 —
  영어를 말하면 영어 그대로 나옵니다.
- **프라이버시** — 모든 처리는 whisper.cpp + Metal로 이 맥 안에서만 일어납니다.
  서버 전송, 계정, 구독 없음. 자세한 내용은 [PRIVACY.md](PRIVACY.md).
- **권한 제로로도 완전 동작** — 손쉬운 사용 권한을 옵트인으로 설계했습니다. 권한 없이
  ⌥Space + 수동 ⌘V만으로도 전체 기능이 동작합니다.

## 사용법

1. 우측 ⌘(또는 설정에서 고른 다른 홀드 키)를 누른 채 말합니다.
2. 손을 떼면 전사된 텍스트가 커서 위치에 바로 입력됩니다.

손쉬운 사용 권한을 허용하고 싶지 않다면 ⌥Space 모드를 선택하세요 — 권한 없이,
전사 결과가 클립보드에 담기고 ⌘V로 직접 붙여넣습니다.

<p align="center">
  <img src="docs/images/settings.png" width="560" alt="받아써 설정 — 음성 입력 단축키(우측 ⌘ 홀드 키 선택)와 사운드">
</p>

## 설치

Homebrew 한 줄이면 됩니다:

```bash
brew install --cask ulBible/tap/badasseo
```

또는 [Releases](https://github.com/ulBible/badasseo/releases)에서 최신 `Badasseo-x.y.z.zip`을
내려받아 압축을 풀고 `Badasseo.app`을 `/Applications`로 드래그하세요. macOS 14 이상 필요.

받아써는 스스로 최신 상태를 유지합니다 — 백그라운드에서 새 릴리스를 확인하고(Sparkle)
있으면 알려줍니다. 메뉴바 아이콘 → **업데이트 확인…**으로 수동 확인도 가능합니다.

### 소스에서 빌드

```bash
git clone https://github.com/ulBible/badasseo.git
cd badasseo
./scripts/bundle.sh release
open build/Badasseo.app
```

**요구사항**: Apple Silicon 맥, macOS 14 이상. 첫 실행 시 음성 인식 모델
(Whisper large-v3-turbo, 약 1.6GB)을 한 번 다운로드합니다.

## 모델 선택

받아써는 stock Whisper large-v3-turbo를 사용합니다. 실제 발화 녹음으로 블라인드
비교 벤치마크를 거쳐 선택했으며, 과정과 수치는 [bench/report.md](bench/report.md)에
공개되어 있습니다.

## 권한

| 권한 | 필요한가 | 용도 |
|---|---|---|
| 없음 | 아니오 | ⌥Space + 수동 ⌘V로 완전 동작 |
| 마이크 | 녹음 시에만 | 단축키를 누르고 있는 동안만 사용, 처리 즉시 폐기 |
| 손쉬운 사용 | 옵트인 | 우측 ⌘ 홀드 감지 + 커서 위치 자동 입력(⌘V 합성)용 |

## 후원

받아써는 무료·오픈소스(MIT)입니다. 도움이 되었다면 후원으로 응원해주세요.

[Sponsor 받아써 ❤️](https://github.com/sponsors/ulBible)

## 라이선스

[MIT](LICENSE)

---

<p align="center">
  <a href="https://github.com/ulBible">
    <img src="docs/brand-logo.png" width="330" alt="Chakchak Works — the last block being set into place">
  </a>
</p>
<p align="center">
  Made by <strong>Chakchak Works</strong> · by <a href="https://github.com/ulBible">ulBible</a>
</p>
