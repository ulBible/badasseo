import SwiftUI
import AVFoundation

struct MicStep: View {
    @ObservedObject var model: OnboardingModel
    @State private var granted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

    var body: some View {
        VStack(spacing: 12) {
            Text("🎙️").font(.system(size: 30))
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
                            if !ok { NSWorkspace.shared.open(URL(string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }
                        }
                    }
                }
                Text("macOS 권한 창이 떠요").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }.padding(40)
    }
}
