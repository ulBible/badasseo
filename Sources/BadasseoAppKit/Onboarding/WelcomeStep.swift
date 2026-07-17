import SwiftUI

struct WelcomeStep: View {
    @ObservedObject var model: OnboardingModel
    var body: some View {
        VStack(spacing: 16) {
            AppIconBadge()
            ProcessDiagram()
            Text("말하면, 받아써.").font(.system(size: 26, weight: .heavy))
            Text("목소리 → 텍스트, 전 과정이 내 맥 안에서.\n서버도, 계정도, 구독도 없어요.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(4)
            OnboardingPrimaryButton(title: "시작하기") { model.next() }
        }
        .glassPanel()
        .padding(24)
    }
}
