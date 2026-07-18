import SwiftUI
import KeyboardShortcuts
import ApplicationServices

struct HotkeyStep: View {
    @ObservedObject var model: OnboardingModel
    @AppStorage("hotkeyMode") private var hotkeyMode = "rightCommand"
    @State private var axTrusted = AXIsProcessTrusted()
    @State private var didPrompt = false
    @State private var poller: Timer?

    /// Mac App Store 빌드는 손쉬운 사용 권한이 필요 없는 ⌥Space 경로를 기본으로 민다
    /// (2.4.5 하드닝 — vClips가 손쉬운 사용 자동붙여넣기로 두 차례 거부된 배경).
    /// GitHub 빌드는 이 분기가 전부 false로 평가되어 기존 동작 그대로다.
    private var isAppStoreVariant: Bool { BuildVariant.current == .appStore }

    var body: some View {
        VStack(spacing: 12) {
            IconBadge(symbol: "command")
            Text("어떻게 말을 걸까요?").font(.system(size: 19, weight: .heavy))

            if isAppStoreVariant {
                optionSpaceCard
                rightCommandCard
            } else {
                rightCommandCard
                optionSpaceCard
            }

            OnboardingPrimaryButton(title: "다음") { model.next() }
            Button("나중에 결정하기 — 설정에서 언제든 바꿀 수 있어요") { model.next() }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .glassPanel()
        .padding(24)
        .onAppear { applyVariantDefaultIfNeeded() }
        .onDisappear { poller?.invalidate() }
    }

    /// MAS 신규 설치 전용 프리셀렉트. hotkeyMode 키 자체가 아직 없을 때만(이번 세션에
    /// 사용자가 아직 아무 것도 고르지 않았을 때만) custom(⌥Space)으로 맞춘다.
    ///
    /// @State 플래그 대신 UserDefaults 키 부재로 가드하는 이유: 온보딩은 step 인덱스로
    /// switch되는 화면이라(OnboardingView) 이 스텝을 벗어났다 스텝 바로 되돌아오면
    /// HotkeyStep 값이 새로 만들어져 @State가 초기화된다 — 세션 한정 플래그로는 재방문을
    /// 걸러낼 수 없지만, UserDefaults 키 존재 여부는 재방문에도 유지된다.
    /// setMode(_:)를 그대로 재사용해 hotkeyMode 저장과 KeyboardShortcuts.enable(.pushToTalk)
    /// 호출을 함께 보장한다 — AppState.init()은 앱 시작 시점(온보딩보다 먼저) hotkeyMode가
    /// 아직 "custom"이 아니었으므로 이미 pushToTalk를 disable한 뒤라, 이 세션에서 실제로
    /// 다시 enable해 주는 코드가 없으면 설정을 안 거친 신규 MAS 설치는 ⌥Space가 무반응이다.
    private func applyVariantDefaultIfNeeded() {
        guard isAppStoreVariant, UserDefaults.standard.object(forKey: "hotkeyMode") == nil else { return }
        setMode("custom")
    }

    /// 우측 ⌘ 카드. GitHub에서는 권장(프리셀렉트) 슬롯을 차지하고, MAS에서는 손쉬운 사용
    /// 권한이 필요한 고급 옵션으로 강등된다. AX 상태 배지/프롬프트 UI는 두 변형 모두
    /// 선택 여부와 무관하게 항상 표시된다(기존 동작 그대로 — 선택 시에만 보이지 않는다).
    @ViewBuilder
    private var rightCommandCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: hotkeyMode == "rightCommand" ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isAppStoreVariant ? .secondary : OnboardingTheme.green)
                Text("우측 ⌘ 누르고 말하기")
                    .font(.system(size: isAppStoreVariant ? 13 : 14, weight: isAppStoreVariant ? .semibold : .bold))
                    .foregroundStyle(isAppStoreVariant ? .secondary : .primary)
                if !isAppStoreVariant {
                    Text("권장").font(.system(size: 10))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(OnboardingTheme.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(OnboardingTheme.green)
                }
            }
            Text("놀고 있는 오른쪽 ⌘ 하나로. 말이 끝나면 커서 위치에 바로 입력돼요.")
                .font(.system(size: isAppStoreVariant ? 11.5 : 12))
                .foregroundStyle(isAppStoreVariant ? .tertiary : .secondary)
            if isAppStoreVariant {
                Text("손쉬운 사용 권한이 필요한 고급 옵션이에요.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
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
        .padding(isAppStoreVariant ? 10 : 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            // GitHub에서만 선택 시 강조 보더 — MAS에서는 이 카드가 강등 슬롯이라 없음
            // (기존 ⌥Space 카드가 GitHub에서 보더 없이 아이콘만으로 선택을 표시하던 것과 동일).
            if !isAppStoreVariant, hotkeyMode == "rightCommand" {
                RoundedRectangle(cornerRadius: 12).stroke(OnboardingTheme.green, lineWidth: 2)
            }
        }
        .onTapGesture { setMode("rightCommand") }
    }

    /// ⌥Space 카드. MAS에서는 권장(프리셀렉트) 슬롯을 차지해 권한 없는 경로를 앞세운다.
    @ViewBuilder
    private var optionSpaceCard: some View {
        VStack(alignment: .leading, spacing: isAppStoreVariant ? 6 : 3) {
            HStack {
                Image(systemName: hotkeyMode == "custom" ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isAppStoreVariant ? OnboardingTheme.green : .secondary)
                Text("⌥Space + 직접 ⌘V")
                    .font(.system(size: isAppStoreVariant ? 14 : 13, weight: isAppStoreVariant ? .bold : .semibold))
                    .foregroundStyle(isAppStoreVariant ? .primary : .secondary)
                if isAppStoreVariant {
                    Text("권한 없이 바로 사용 (권장)").font(.system(size: 10))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(OnboardingTheme.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(OnboardingTheme.green)
                }
            }
            Text("권한 없이 사용. 전사 결과가 클립보드에 담겨요.")
                .font(.system(size: isAppStoreVariant ? 12 : 11.5))
                .foregroundStyle(isAppStoreVariant ? .secondary : .tertiary)
        }
        .padding(isAppStoreVariant ? 12 : 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            // MAS에서만 선택 시 강조 보더(권장 슬롯) — GitHub에서는 기존처럼 보더 없음.
            if isAppStoreVariant, hotkeyMode == "custom" {
                RoundedRectangle(cornerRadius: 12).stroke(OnboardingTheme.green, lineWidth: 2)
            }
        }
        .onTapGesture { setMode("custom") }
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
