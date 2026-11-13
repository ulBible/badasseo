# 받아써 개인정보 처리방침

_최종 수정: 2026년 11월 13일_

받아써는 macOS용 한국어 음성입력 앱입니다. 프라이버시 원칙은 단순합니다 —
**받아써는 아무것도 수집하지 않습니다.**

## 처리 방식

- 음성 인식(전사)은 전부 이 맥 위에서, whisper.cpp(Metal)로 로컬 실행됩니다.
  녹음된 오디오가 네트워크로 전송되는 일은 없습니다.
- 오디오는 전사 처리 직후 즉시 폐기되며 디스크에 저장되지 않습니다.
- 네트워크 연결은 딱 하나 — 최초 실행 시 음성 인식 모델(Whisper large-v3-turbo)을
  Hugging Face에서 내려받는 것뿐입니다. 모델을 이미 받았다면 그 이후로는 인터넷 연결
  없이도 완전히 동작합니다.

## 로컬에 저장되는 것

- **커스텀 사전** — 사용자가 설정에서 추가한 `{말한 것 → 쓸 것}` 항목. 로컬 JSON 파일.
- **입력 히스토리** — 최근 전사 결과 최대 500개. 로컬 JSON 파일, 설정 창 히스토리
  탭에서 전체 삭제 가능.
- **진단 로그** — 받아쓰기마다 걸린 시간·오디오 길이·메모리 상태 같은 수치와 처리 결과의
  종류(붙여넣음, 클립보드 복사, 명령 등), 그리고 손쉬운 사용 권한이 켜지거나 꺼진 시점을
  macOS 통합 로그에 남깁니다(느려졌을 때 원인을 찾기 위한 것). 말한 내용, 오디오, 어느
  앱에서 썼는지는 남기지 않습니다. 이 로그는 macOS가 관리하며 시간이 지나면 지워집니다.
- 위 항목은 모두 이 맥을 벗어나지 않습니다.

## 받아써가 하지 않는 것

- 전송·수집·분석·텔레메트리·크래시 리포팅 없음.
- 계정, 식별자, 제3자 서비스 없음.
- 구독·결제 없음.

## 클립보드 처리

전사 텍스트를 커서 위치에 넣기 위해 클립보드를 잠깐 사용합니다. 기존 클립보드
내용은 삽입 직후 원래대로 복원되며, 전사 텍스트에는 `org.nspasteboard.ConcealedType`
마커를 붙여 vClips 등 클립보드 매니저가 이를 이력에 기록하지 않도록 합니다.

자동 입력 없이 클립보드에만 담는 경우(손쉬운 사용 권한이 없을 때, 암호 입력 칸, 받아쓰는
사이 다른 앱으로 넘어갔을 때)에는 전사 텍스트가 클립보드에 남고 이전 내용은 복원되지
않습니다.

## 권한

- **마이크** — 단축키를 누르고 있는 동안에만 사용. 거부해도 앱은 동작하지 않으며
  (음성입력 앱의 핵심 기능이므로) 시스템 설정으로 안내합니다.
- **손쉬운 사용** (옵트인) — 우측 ⌘ 홀드 감지와 커서 위치 자동 입력(⌘V 합성)에만
  사용됩니다. 거부해도 ⌥Space + 수동 ⌘V로 전체 기능을 그대로 쓸 수 있습니다.

## 데이터 삭제

설정 창 히스토리 탭에서 전체 삭제가 가능합니다. 앱을 제거할 때 저장된 데이터
(사전·히스토리·모델)까지 지우려면 `~/Library/Application Support/Badasseo` 폴더를
삭제하세요 — macOS는 앱을 지워도 이 폴더를 자동으로 지우지 않습니다.

## 문의

<https://github.com/ulBible/badasseo/issues>에 이슈를 남겨주세요.

---

# Badasseo Privacy Policy

_Last updated: November 13, 2026_

Badasseo is a Korean voice-input app for macOS. Our privacy principle is simple —
**Badasseo collects nothing.**

## How processing works

- Speech recognition (transcription) runs entirely on your Mac via whisper.cpp
  (Metal). Recorded audio is never sent over the network.
- Audio is discarded immediately after transcription and never written to disk.
- There is exactly one network connection: downloading the Korean recognition
  model (Whisper large-v3-turbo) from Hugging Face on first launch. Once the
  model is downloaded, Badasseo works fully offline.

## What's stored locally

- **Custom dictionary** — the `{spoken → written}` entries you add in Settings.
  A local JSON file.
- **Input history** — up to the last 500 transcriptions. A local JSON file,
  viewable and clearable from the Settings History tab.
- **Diagnostic log** — for each dictation, figures such as how long it took, the
  audio length and the memory state, the kind of outcome (pasted, copied to the
  clipboard, command, …), and the moments Accessibility permission was turned on
  or off are written to the macOS unified log (to find the cause when it gets
  slow). Never what you said, never audio, never which app you were using. macOS
  manages that log and it expires over time.
- All of the above stay on your Mac.

## What Badasseo does NOT do

- No network transmission, collection, analytics, telemetry, or crash reporting.
- No accounts, no identifiers, no third-party services.
- No subscriptions, no payments.

## Clipboard handling

Badasseo briefly uses the clipboard to insert transcribed text at your cursor.
Your prior clipboard contents are restored immediately after insertion, and the
transcribed text is tagged with the `org.nspasteboard.ConcealedType` marker so
clipboard managers (e.g. vClips) don't record it in their history.

When the text is only copied instead of inserted (no Accessibility permission, a
password field, or you switched apps while it was transcribing), it stays on the
clipboard and the previous contents are not restored.

## Permissions

- **Microphone** — used only while you hold the shortcut key. If denied, the
  app can't do its core job and points you to System Settings.
- **Accessibility** (opt-in) — used solely to detect the right-⌘ hold and to
  auto-insert text at your cursor (synthesized ⌘V). If denied, ⌥Space +
  manual ⌘V still gives you the full feature set.

## Data deletion

Clear the entire history from the Settings History tab. To remove all stored
data (dictionary, history, model) when uninstalling, delete
`~/Library/Application Support/Badasseo` — macOS does not remove this folder
automatically when you delete the app.

## Contact

Questions: open an issue at <https://github.com/ulBible/badasseo/issues>.
