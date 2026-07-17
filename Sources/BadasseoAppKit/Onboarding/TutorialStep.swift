import SwiftUI
import BadasseoCore
import BadasseoEngine

struct TutorialStep: View {
    @ObservedObject var model: OnboardingModel
    @AppStorage("hotkeyMode") private var hotkeyMode = "rightCommand"
    @State private var text = ""
    @State private var success = false

    private var keyName: String { hotkeyMode == "rightCommand" ? "\(HoldKey.current.displayName)를" : "⌥Space를" }

    var body: some View {
        let ax = TextInserter.hasAccessibility
        VStack(spacing: 12) {
            Text(success ? "🎉 완벽해요!" : "해볼까요?").font(.system(size: 19, weight: .heavy))
            if !success {
                if hotkeyMode == "rightCommand" && !ax {
                    Text("우측 ⌘ 감지에는 손쉬운 사용 권한이 필요해요.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("권한 단계로 돌아가기") { model.step = 3 }
                        .buttonStyle(.borderedProminent).tint(OnboardingTheme.green).controlSize(.small)
                } else {
                    ListeningWave()
                    Text("아래 칸에 커서를 두고, \(keyName) 누른 채\n\"안녕하세요 받아써\"라고 말해보세요")
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
            if success {
                Text("이제 어디서든 이렇게 쓰면 돼요. 메뉴바에서 만나요!")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                OnboardingPrimaryButton(title: "받아써 시작") { model.finish() }
            } else {
                Text(!ax ? "권한이 없어 클립보드에 담겨요 — 말한 뒤 이 칸에 ⌘V 하세요" : " ")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                Button("건너뛰기") { model.finish() }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .glassPanel()
        .padding(24)
    }
}
