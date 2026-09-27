import SwiftUI
import AppKit
import ApplicationServices
import KeyboardShortcuts
import BadasseoCore

/// 설정 › 일반의 "음성 입력 단축키" 카드. 녹음 키를 한 목록에서 고르고, 그 키가 지금
/// 다른 앱에서 동작하는지(손쉬운 사용 권한)를 바로 아래에 보여준다.
///
/// 저장은 기존 `hotkeyMode`·`holdKey` 두 키 그대로 — `HotkeyChoice`가 변환한다.
/// 두 값을 각각 @AppStorage로 구독해야 어느 쪽이 바뀌어도 다시 그려진다.
struct HotkeySettingsCard: View {
    @AppStorage(HotkeyChoice.modeKey) private var hotkeyMode = HotkeyChoice.hold(.rightCommand).mode
    @AppStorage(HoldKey.defaultsKey) private var holdKey = HoldKey.rightCommand.rawValue
    @State private var axTrusted = AXIsProcessTrusted()
    @State private var poller: Timer?

    private var isAppStore: Bool { BuildVariant.current == .appStore }
    private var current: HotkeyChoice { HotkeyChoice(mode: hotkeyMode, holdKey: holdKey) }

    private var selection: Binding<HotkeyChoice> {
        Binding(
            get: { current },
            set: { choice in
                hotkeyMode = choice.mode
                if let key = choice.holdKey { holdKey = key.rawValue }
                // 등록만으로도 조합 키가 전역 소비되므로, 조합 키일 때만 Carbon 핫키 활성
                if choice == .combo { KeyboardShortcuts.enable(.pushToTalk) }
                else { KeyboardShortcuts.disable(.pushToTalk) }
            })
    }

    var body: some View {
        SettingsCard(title: L("음성 입력 단축키")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("누르고 있는 동안 녹음할 키")).font(.callout)
                Picker("", selection: selection) {
                    ForEach(HotkeyChoice.options(appStore: isAppStore), id: \.self) { choice in
                        Text(label(for: choice)).tag(choice)
                    }
                }
                .pickerStyle(.radioGroup).labelsHidden()
                if current == .combo {
                    KeyboardShortcuts.Recorder(L("조합 키"), name: .pushToTalk)
                }
                status
            }
        }
        .onAppear { axTrusted = AXIsProcessTrusted() }
        // 시스템 설정에서 직접 켜고 돌아온 경로(허용 버튼 폴러를 거치지 않음)도 반영
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            axTrusted = AXIsProcessTrusted()
        }
        .onDisappear { poller?.invalidate(); poller = nil }
    }

    /// "(기본)"은 변형별 실제 기본값에만 — GitHub은 우측 ⌘, 앱스토어는 조합 키(⌥Space).
    /// 우측 ⌃는 맥북 내장 키보드에 없는 키라 외장 키보드용임을 라벨에 밝힌다.
    private func label(for choice: HotkeyChoice) -> String {
        switch choice {
        case .hold(.rightCommand) where !isAppStore: L("우측 ⌘ (기본)")
        case .hold(.rightControl): L("우측 ⌃ (외장 키보드)")
        case .hold(let key): L(String.LocalizationValue(key.displayName))
        case .combo: isAppStore ? L("조합 키 (기본 ⌥Space)") : L("조합 키 직접 지정")
        }
    }

    @ViewBuilder
    private var status: some View {
        switch current {
        case .hold(let key):
            if axTrusted {
                Text(L("\(L(String.LocalizationValue(key.displayName)))만 눌러 유지하는 동안 녹음돼요. 다른 키와 조합하면 녹음되지 않아요."))
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Label(L("손쉬운 사용 권한이 꺼져 있어 다른 앱에서는 이 키가 동작하지 않아요."),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
                Button(L("손쉬운 사용 허용하기")) { requestAccessibility() }
                    .controlSize(.small)
            }
            if key == .fn {
                Text(L("fn을 누를 때 이모지 창이 뜨거나 입력 소스가 바뀌면, 시스템 설정 › 키보드에서 🌐 키를 눌렀을 때 아무 동작도 하지 않도록 바꿔 주세요."))
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .combo:
            Text(L("지정한 조합을 누르고 있는 동안 녹음돼요."))
                .font(.callout).foregroundStyle(.secondary)
            if !axTrusted {
                Text(L("권한 없이 사용. 전사 결과가 클립보드에 담겨요."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    /// 온보딩 HotkeyStep.promptAX()와 같은 경로 — 시스템 프롬프트 후 1초 폴링, 켜지는 즉시
    /// 안내를 바꾸고 AppState가 전역 모니터를 설치하도록 브로드캐스트한다.
    private func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        poller?.invalidate()
        poller = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                guard AXIsProcessTrusted() else { return }
                axTrusted = true
                poller?.invalidate()
                poller = nil
                NotificationCenter.default.post(name: .badasseoAXGranted, object: nil)
            }
        }
    }
}
