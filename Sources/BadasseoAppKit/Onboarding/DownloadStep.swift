import SwiftUI
import BadasseoCore
import BadasseoEngine

struct DownloadStep: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject var store: ModelStore
    init(model: OnboardingModel) { self.model = model; self.store = model.modelStore }

    var body: some View {
        VStack(spacing: 12) {
            IconBadge(symbol: "cpu")
            Text({
                if case .ready = store.state { L("음성 인식 모델이 준비됐어요") }
                else { L("음성 인식 모델을 받는 중이에요") }
            }()).font(.system(size: 19, weight: .heavy))
            Text(L("Whisper large-v3-turbo · 1.6GB · 처음 한 번만\n한국어에 최적화, 영어가 섞여도 그대로 받아써요"))
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(3)
            switch store.state {
            case .downloading(let p):
                ProgressView(value: p).frame(maxWidth: 300).tint(OnboardingTheme.green)
                Text("\(Int(p * Double(ModelInfo.byteSize)) / 1_048_576)MB / \(Int(ModelInfo.byteSize) / 1_048_576)MB")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Text(L("받는 동안 다음 단계를 진행할 수 있어요 →"))
                    .font(.system(size: 12)).foregroundStyle(OnboardingTheme.green)
            case .verifying:
                ProgressView().controlSize(.small)
                Text(L("파일 무결성 확인 중…")).font(.system(size: 12)).foregroundStyle(.secondary)
            case .ready:
                Label(L("준비 완료"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(OnboardingTheme.green)
            case .failed(let msg):
                Text(msg).font(.system(size: 12)).foregroundStyle(.red)
                Button(L("다시 받기")) { store.startDownload() }
            case .idle: ProgressView().controlSize(.small)
            }
            OnboardingPrimaryButton(title: L("다음")) { model.next() }
        }
        .glassPanel()
        .padding(24)
    }
}
