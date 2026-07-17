import SwiftUI
import KeyboardShortcuts
import ApplicationServices

struct HotkeyStep: View {
    @ObservedObject var model: OnboardingModel
    @AppStorage("hotkeyMode") private var hotkeyMode = "rightCommand"
    @State private var axTrusted = AXIsProcessTrusted()
    @State private var didPrompt = false
    @State private var poller: Timer?

    var body: some View {
        VStack(spacing: 12) {
            IconBadge(symbol: "command")
            Text("어떻게 말을 걸까요?").font(.system(size: 19, weight: .heavy))

            // 권장: 우측 ⌘ (프리셀렉트)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: hotkeyMode == "rightCommand" ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(OnboardingTheme.green)
                    Text("우측 ⌘ 누르고 말하기").font(.system(size: 14, weight: .bold))
                    Text("권장").font(.system(size: 10))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(OnboardingTheme.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(OnboardingTheme.green)
                }
                Text("놀고 있는 오른쪽 ⌘ 하나로. 말이 끝나면 커서 위치에 바로 입력돼요.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                if axTrusted {
                    Label("손쉬운 사용: 켜짐", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(OnboardingTheme.green)
                } else {
                    Label("손쉬운 사용: 꺼짐", systemImage: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.orange)
                    HStack(spacing: 8) {
                        Button("손쉬운 사용 허용하기") { promptAX() }
                            .buttonStyle(.borderedProminent).tint(OnboardingTheme.green).controlSize(.small)
                        Text("단축키 감지·자동 입력에 이 권한 하나만 써요")
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                    if didPrompt {
                        Text("시스템 설정이 열렸어요. 목록에서 '받아써'를 찾아\n스위치를 켜면 자동으로 다음으로 넘어가요.")
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("설정 다시 열기") { reopenSettings() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(hotkeyMode == "rightCommand" ? OnboardingTheme.green : .clear, lineWidth: 2))
            .onTapGesture { setMode("rightCommand") }

            // 대안: ⌥Space (작게)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: hotkeyMode == "custom" ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(.secondary)
                    Text("⌥Space + 직접 ⌘V").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                }
                Text("권한 없이 사용. 전사 결과가 클립보드에 담겨요.")
                    .font(.system(size: 11.5)).foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .onTapGesture { setMode("custom") }

            OnboardingPrimaryButton(title: "다음") { model.next() }
            Button("나중에 결정하기 — 설정에서 언제든 바꿀 수 있어요") { model.next() }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .glassPanel()
        .padding(24)
        .onDisappear { poller?.invalidate() }
    }

    private func setMode(_ mode: String) {
        hotkeyMode = mode
        if mode == "custom" { KeyboardShortcuts.enable(.pushToTalk) }
        else { KeyboardShortcuts.disable(.pushToTalk) }
    }

    private func promptAX() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        didPrompt = true
        poller?.invalidate()
        poller = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if AXIsProcessTrusted() {
                    axTrusted = true
                    poller?.invalidate()
                    OnboardingModel.bringToFront()  // 시스템 설정에서 돌아온 뒤 창을 앞으로
                    NotificationCenter.default.post(name: .badasseoAXGranted, object: nil)
                }
            }
        }
    }

    private func reopenSettings() {
        NSWorkspace.shared.open(URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
