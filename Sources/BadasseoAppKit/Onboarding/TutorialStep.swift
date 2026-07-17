import SwiftUI
import BadasseoCore
import BadasseoEngine

struct TutorialStep: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject var store: ModelStore
    @AppStorage("hotkeyMode") private var hotkeyMode = "rightCommand"
    @State private var text = ""
    @State private var success = false

    init(model: OnboardingModel) { self.model = model; self.store = model.modelStore }

    private var keyName: String { hotkeyMode == "rightCommand" ? "\(HoldKey.current.displayName)를" : "⌥Space를" }

    var body: some View {
        let ax = TextInserter.hasAccessibility
        VStack(spacing: 12) {
            Text(success ? "🎉 완벽해요!" : "해볼까요?").font(.system(size: 19, weight: .heavy))
            if !success {
                if store.state != .ready {
                    Text("모델을 받는 중이에요 — 조금만 기다려 주세요")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    switch store.state {
                    case .downloading(let p):
                        ProgressView(value: p).frame(maxWidth: 240).tint(OnboardingTheme.green)
                    case .failed(let msg):
                        Text(msg).font(.system(size: 11)).foregroundStyle(.red)
                        Button("다시 받기") { store.startDownload() }
                            .buttonStyle(.borderedProminent).tint(OnboardingTheme.green).controlSize(.small)
                    default:
                        ProgressView().controlSize(.small)
                    }
                } else if hotkeyMode == "rightCommand" && !ax {
                    Text("\(HoldKey.current.displayName) 감지에는 손쉬운 사용 권한이 필요해요.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("권한 단계로 돌아가기") { model.step = 3 }
                        .buttonStyle(.borderedProminent).tint(OnboardingTheme.green).controlSize(.small)
                } else {
                    ListeningWave()
                    Text("아래 칸에 커서를 두고, \(keyName) 누른 채\n\"오늘 날씨가 참 좋네요\"라고 말해보세요")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).lineSpacing(4)
                }
            }
            TextEditor(text: $text)
                .font(.system(size: 14))
                .frame(maxWidth: 320, minHeight: 64, maxHeight: 64)
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(OnboardingTheme.green, style: StrokeStyle(lineWidth: 2, dash: success ? [] : [5])))
                .onChange(of: text) { _, new in
                    if !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { success = true }
                }
                .onReceive(NotificationCenter.default.publisher(for: .badasseoDidTranscribe)) { note in
                    if let t = note.object as? String { text = t }
                }
            if success {
                Text("이제 어디서든 이렇게 쓰면 돼요. 메뉴바에서 만나요!")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                OnboardingPrimaryButton(title: "받아써 시작") { model.finish() }
            } else {
                Text(!ax ? "말하면 이 칸에 바로 나타나요 (권한이 없어도 튜토리얼은 동작해요)" : " ")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                Button("건너뛰기") { model.finish() }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .glassPanel()
        .padding(24)
    }
}
