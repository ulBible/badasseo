import SwiftUI

struct OnboardingView: View {
    @StateObject private var model = OnboardingModel()

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 0) {
                Group {
                    switch model.step {
                    case 0: WelcomeStep(model: model)
                    case 1: DownloadStep(model: model)
                    case 2: MicStep(model: model)
                    case 3: HotkeyStep(model: model)
                    default: TutorialStep(model: model)
                    }
                }
                .frame(maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)))
                StepBar(current: model.step)
                    .padding(.bottom, 18)
            }
            .animation(.spring(duration: 0.4), value: model.step)
        }
        .frame(width: 560, height: 500)
        .onAppear { model.modelStore.ensureModel() }  // 다운로드는 온보딩 시작과 동시에 병행
    }
}
