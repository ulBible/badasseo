import SwiftUI

struct OnboardingView: View {
    @StateObject private var model = OnboardingModel()
    // 화면에 실제로 그리는 단계와 전환 방향. model.step 변경을 onChange에서 받아
    // 방향을 먼저 정한 뒤 애니메이션하므로, 뒤로 갈 땐 새 화면이 왼쪽에서 들어온다.
    @State private var displayedStep = 0
    @State private var insertEdge: Edge = .trailing

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 0) {
                Group {
                    switch displayedStep {
                    case 0: WelcomeStep(model: model)
                    case 1: DownloadStep(model: model)
                    case 2: MicStep(model: model)
                    case 3: HotkeyStep(model: model)
                    default: TutorialStep(model: model)
                    }
                }
                .frame(maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: insertEdge).combined(with: .opacity),
                    removal: .move(edge: insertEdge == .trailing ? .leading : .trailing)
                        .combined(with: .opacity)))
                StepBar(current: model.step, onSelect: { model.step = $0 })
                    .padding(.bottom, 18)
            }
        }
        .frame(width: 560, height: 500)
        .onAppear { model.modelStore.ensureModel() }  // 다운로드는 온보딩 시작과 동시에 병행
        .onChange(of: model.step) { old, new in
            guard new != displayedStep else { return }
            insertEdge = new > old ? .trailing : .leading
            withAnimation(.spring(duration: 0.4)) { displayedStep = new }
        }
    }
}
