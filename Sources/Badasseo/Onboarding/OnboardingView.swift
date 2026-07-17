import SwiftUI

struct OnboardingView: View {
    @StateObject private var model = OnboardingModel()

    var body: some View {
        ZStack {
            OnboardingTheme.background.ignoresSafeArea()
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
                HStack(spacing: 6) {   // 점 인디케이터
                    ForEach(0..<5, id: \.self) { i in
                        Circle().fill(i == model.step ? Color.primary : Color.primary.opacity(0.15))
                            .frame(width: 6, height: 6)
                    }
                }.padding(.bottom, 18)
            }
        }
        .frame(width: 560, height: 480)
        .onAppear { model.modelStore.ensureModel() }  // 다운로드는 온보딩 시작과 동시에 병행
    }
}
