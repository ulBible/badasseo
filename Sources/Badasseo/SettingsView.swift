import SwiftUI
import KeyboardShortcuts
import BadasseoCore

/// 커스텀 사전 편집 — 편집 즉시 저장, 다음 전사부터 반영.
struct SettingsView: View {
    @State private var rows: [DictionaryRows.Row] = []
    @AppStorage("hotkeyMode") private var hotkeyMode = "rightCommand"
    @AppStorage("soundFeedback") private var soundFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("음성 입력 단축키").font(.headline)
            Picker("", selection: $hotkeyMode) {
                Text("우측 ⌘ 누르고 말하기 (기본)").tag("rightCommand")
                Text("사용자 지정 조합").tag("custom")
            }
            .pickerStyle(.radioGroup).labelsHidden()
            if hotkeyMode == "custom" {
                KeyboardShortcuts.Recorder("조합 키", name: .pushToTalk)
            }
            Text(hotkeyMode == "rightCommand"
                 ? "우측 ⌘만 눌러 유지하는 동안 녹음돼요. 다른 키와 조합하면 녹음되지 않아요."
                 : "지정한 조합을 누르고 있는 동안 녹음돼요.")
                .font(.callout).foregroundStyle(.secondary)
            Divider()
            Text("커스텀 사전").font(.headline)
            Text("말한 것을 원하는 표기로 바꿔요. 예: \"깃허브\" → \"GitHub\"")
                .font(.callout).foregroundStyle(.secondary)
            List {
                ForEach($rows) { $row in
                    HStack {
                        TextField("말한 것", text: $row.spoken)
                        Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                        TextField("쓸 것", text: $row.written)
                        Button {
                            rows.removeAll { $0.id == row.id }
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                    .opacity(row.isValid ? 1 : 0.4)  // 빈 키/값 행 흐림 (저장 제외 표시)
                }
            }
            .frame(minHeight: 260)
            HStack {
                Button {
                    rows.append(DictionaryRows.Row(spoken: "", written: ""))
                } label: { Label("추가", systemImage: "plus") }
                Spacer()
                Button("기본 사전 복원") {
                    rows = DictionaryRows.rows(from: UserDictionary.defaultSeed)
                }
            }
            Divider()
            Toggle("입력 시작/종료음", isOn: $soundFeedback)
            Text("받아써의 기본은 무음이에요. 켜면 절제된 키 사운드가 재생돼요.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 440)
        .onAppear { rows = DictionaryRows.rows(from: UserDictionary.standard.load()) }
        .onChange(of: rows) { _, newRows in
            UserDictionary.standard.save(DictionaryRows.dictionary(from: newRows))
        }
    }
}
