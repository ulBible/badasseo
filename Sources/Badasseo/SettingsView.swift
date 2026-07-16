import SwiftUI
import BadasseoCore

/// 커스텀 사전 편집 — 편집 즉시 저장, 다음 전사부터 반영.
struct SettingsView: View {
    @State private var rows: [DictionaryRows.Row] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        }
        .padding(16)
        .frame(width: 440)
        .onAppear { rows = DictionaryRows.rows(from: UserDictionary.standard.load()) }
        .onChange(of: rows) { _, newRows in
            UserDictionary.standard.save(DictionaryRows.dictionary(from: newRows))
        }
    }
}
