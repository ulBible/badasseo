import SwiftUI

struct TutorialStep: View {
    @ObservedObject var model: OnboardingModel
    @AppStorage("hotkeyMode") private var hotkeyMode = "rightCommand"
    @State private var text = ""
    @State private var success = false

    private var keyName: String { hotkeyMode == "rightCommand" ? "우측 ⌘를" : "⌥Space를" }

    var body: some View {
        VStack(spacing: 12) {
            Text(success ? "🎉 완벽해요!" : "해볼까요?").font(.system(size: 19, weight: .heavy))
            if !success {
                Text("아래 칸에 커서를 두고, \(keyName) 누른 채\n\"안녕하세요 받아써\"라고 말해보세요")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).lineSpacing(4)
            }
            TextEditor(text: $text)
                .font(.system(size: 14))
                .frame(maxWidth: 320, minHeight: 64, maxHeight: 64)
                .padding(8)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
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
                Text(hotkeyMode == "custom" ? "클립보드 모드예요 — 말한 뒤 이 칸에 ⌘V 하세요" : " ")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                Button("건너뛰기") { model.finish() }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }.padding(36)
    }
}
