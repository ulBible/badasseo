import SwiftUI
import AVFoundation

struct MicStep: View {
    @ObservedObject var model: OnboardingModel
    @State private var granted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var poller: Timer?

    var body: some View {
        VStack(spacing: 12) {
            IconBadge(symbol: "mic.fill")
            Text("목소리를 들을 수 있게 해주세요").font(.system(size: 19, weight: .heavy))
            Text("녹음은 단축키를 누르는 동안에만.\n소리는 처리 즉시 사라지고, 이 맥 밖으로 나가지 않아요.")
                .font(.system(size: 12.5)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(4)
            if granted {
                Label("허용됨", systemImage: "checkmark.circle.fill").foregroundStyle(OnboardingTheme.green)
                OnboardingPrimaryButton(title: "다음") { model.next() }
            } else {
                OnboardingPrimaryButton(title: "마이크 허용") {
                    AVCaptureDevice.requestAccess(for: .audio) { ok in
                        Task { @MainActor in
                            granted = ok
                            // 권한 대화상자 응답 후 LSUIElement 앱은 뒤로 밀린다 —
                            // 온보딩 창을 다시 앞으로.
                            OnboardingModel.bringToFront()
                            if !ok {
                                NSWorkspace.shared.open(URL(string:
                                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                                startPolling()
                            }
                        }
                    }
                }
                Text("macOS 권한 창이 떠요").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .glassPanel()
        .padding(24)
        .onDisappear { poller?.invalidate() }
    }

    private func startPolling() {
        poller?.invalidate()
        poller = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                    granted = true
                    poller?.invalidate()
                    // 시스템 설정 왕복 후 LSUIElement 앱은 뒤로 밀린다 — 창을 다시 앞으로.
                    OnboardingModel.bringToFront()
                }
            }
        }
    }
}
