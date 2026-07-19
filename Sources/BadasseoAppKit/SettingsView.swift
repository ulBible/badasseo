import SwiftUI
import KeyboardShortcuts
import BadasseoCore

struct SettingsView: View {
    enum Pane: String, CaseIterable, Identifiable, Hashable {
        case general, commands, dictionary, history
        var id: String { rawValue }
        var title: String { ["general":"일반","commands":"음성 명령","dictionary":"사전","history":"히스토리"][rawValue]! }
        var symbol: String { ["general":"gearshape","commands":"arrow.turn.down.left","dictionary":"character.book.closed","history":"clock"][rawValue]! }
    }
    @State private var pane: Pane = .general
    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { p in
                Label(p.title, systemImage: p.symbol).tag(p)
            }
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 28) }
            .navigationSplitViewColumnWidth(150)
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch pane {
                case .general: GeneralTab()
                case .commands: CommandsTab()
                case .dictionary: DictionaryTab()
                case .history: HistoryTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 680, height: 520)
        .toolbarBackground(.hidden, for: .windowToolbar)
    }
}

/// 설정 섹션 카드 — 헤더 + 유리질 배경(온보딩 톤과 통일, 라이트/다크 대응).
struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary).textCase(.uppercase)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
    }
}

/// 단축키·사운드·시작 설정.
struct GeneralTab: View {
    @AppStorage("hotkeyMode") private var hotkeyMode = "rightCommand"
    @AppStorage("soundFeedback") private var soundFeedback = true
    @AppStorage(HoldKey.defaultsKey) private var holdKey = HoldKey.rightCommand.rawValue
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?
    /// 아래 revert가 스스로 트리거하는 onChange를 사용자 조작과 구분하는 가드.
    /// 실시간 SMAppService 상태로 가드하면 self-signed 앱이 .requiresApproval
    /// (isEnabled false)에 머물며 등록은 유지된 상태에서 OFF가 영원히 no-op이 된다.
    @State private var revertingLaunchAtLogin = false

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "음성 입력 단축키") {
                VStack(alignment: .leading, spacing: 10) {
                    // "(기본)" 라벨은 변형별 실제 기본과 일치해야 한다 — MAS는 ⌥Space(custom)가
                    // 기본(온보딩 프리셀렉트·심사 노트와 동일 축), GitHub은 우측 ⌘.
                    Picker("", selection: $hotkeyMode) {
                        if BuildVariant.current == .appStore {
                            Text("우측 ⌘ 누르고 말하기 (고급 — 손쉬운 사용 권한 필요)").tag("rightCommand")
                            Text("단축키 조합 (기본 ⌥Space)").tag("custom")
                        } else {
                            Text("우측 ⌘ 누르고 말하기 (기본)").tag("rightCommand")
                            Text("사용자 지정 조합").tag("custom")
                        }
                    }
                    .pickerStyle(.radioGroup).labelsHidden()
                    .onChange(of: hotkeyMode) { _, mode in
                        // 등록만으로도 조합 키가 전역 소비되므로, custom일 때만 Carbon 핫키 활성
                        if mode == "custom" { KeyboardShortcuts.enable(.pushToTalk) }
                        else { KeyboardShortcuts.disable(.pushToTalk) }
                    }
                    if hotkeyMode == "rightCommand" {
                        Picker("홀드 키", selection: $holdKey) {
                            ForEach(HoldKey.allCases, id: \.rawValue) { k in Text(k.displayName).tag(k.rawValue) }
                        }.pickerStyle(.menu).frame(maxWidth: 200)
                        Text("외부 키보드에 우측 ⌘가 없다면 다른 키를 선택하세요.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if hotkeyMode == "custom" {
                        KeyboardShortcuts.Recorder("조합 키", name: .pushToTalk)
                    }
                    Text(hotkeyMode == "rightCommand"
                         ? "\((HoldKey(rawValue: holdKey) ?? .rightCommand).displayName)만 눌러 유지하는 동안 녹음돼요. 다른 키와 조합하면 녹음되지 않아요."
                         : "지정한 조합을 누르고 있는 동안 녹음돼요.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            SettingsCard(title: "사운드") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("입력 시작/종료음", isOn: $soundFeedback)
                    Text("녹음 시작/종료에 절제된 키 사운드가 재생돼요. 끄면 완전 무음으로 동작해요.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            SettingsCard(title: "시작") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("로그인 시 자동 실행", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in
                            if revertingLaunchAtLogin { revertingLaunchAtLogin = false; return }
                            do {
                                try LaunchAtLogin.set(enabled: enabled)
                                launchAtLoginError = nil
                            } catch {
                                launchAtLoginError = error.localizedDescription
                                let actual = LaunchAtLogin.isEnabled
                                if launchAtLogin != actual {
                                    revertingLaunchAtLogin = true
                                    launchAtLogin = actual
                                }
                            }
                        }
                    if let launchAtLoginError {
                        Text(launchAtLoginError)
                            .font(.callout).foregroundStyle(.red)
                    }
                    Text("맥을 켜면 받아써가 메뉴바에 자동으로 상주해요.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

/// 음성 명령 — 발화 끝 키워드로 키 입력·취소를 실행. 트리거 단어는 명령별 커스텀.
struct CommandsTab: View {
    @AppStorage(VoiceCommandSettings.enabledKey) private var enabled = true

    var body: some View {
        VStack(spacing: 14) {
            SettingsCard(title: "음성 명령") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("발화 끝 명령어 인식", isOn: $enabled)
                    Text("발화의 마지막 단어가 명령어면, 그 단어를 빼고 입력한 뒤 동작을 실행해요. 예: \"확인했습니다 엔터\" → 텍스트 입력 후 Enter 키.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            SettingsCard(title: "명령어") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(VoiceCommand.allCases, id: \.rawValue) { command in
                        CommandTriggerRow(command: command)
                    }
                    Text("쉼표로 구분해 여러 단어를 등록할 수 있어요 (예: 엔터, 전송, 보내기). 비우면 그 명령은 꺼져요.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

/// 명령 한 줄: 라벨 + 트리거 단어 입력칸. 편집 즉시 UserDefaults 저장 (사전 탭과 동일 패턴).
struct CommandTriggerRow: View {
    let command: VoiceCommand
    @State private var words: String

    init(command: VoiceCommand) {
        self.command = command
        _words = State(initialValue:
            UserDefaults.standard.string(forKey: VoiceCommandSettings.triggersKey(command))
            ?? command.defaultTrigger)
    }

    var body: some View {
        // 사전 탭("말한 것 → 쓸 것")과 같은 방향: 말하는 단어 → 실행되는 동작.
        HStack {
            TextField("예: \(command.defaultTrigger)", text: $words)
                .textFieldStyle(.roundedBorder)
                .onChange(of: words) { _, newValue in
                    UserDefaults.standard.set(
                        newValue, forKey: VoiceCommandSettings.triggersKey(command))
                }
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            Text(command.displayName)
                .frame(width: 160, alignment: .leading)
        }
    }
}

/// 커스텀 사전 편집 — 편집 즉시 저장, 다음 전사부터 반영.
struct DictionaryTab: View {
    @State private var rows: [DictionaryRows.Row] = []

    var body: some View {
        SettingsCard(title: "커스텀 사전") {
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
                .frame(maxHeight: .infinity)
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
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onAppear { rows = DictionaryRows.rows(from: UserDictionary.standard.load()) }
        .onChange(of: rows) { _, newRows in
            UserDictionary.standard.save(DictionaryRows.dictionary(from: newRows))
        }
    }
}

/// 최근 전사 결과 열람·복사·삭제.
struct HistoryTab: View {
    @State private var entries: [HistoryEntry] = []
    var body: some View {
        SettingsCard(title: "최근 인식된 텍스트") {
            VStack(alignment: .leading, spacing: 10) {
                Text("최대 500개까지 이 맥에만 저장돼요.")
                    .font(.callout).foregroundStyle(.secondary)
                List(entries.indices, id: \.self) { i in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entries[i].text).lineLimit(2)
                            Text(entries[i].date, style: .date).font(.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(entries[i].text, forType: .string)  // 의도된 복사 — 마커 없음
                        } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless)
                    }
                }
                .frame(maxHeight: .infinity)
                HStack {
                    Text("\(entries.count)개").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("모두 지우기", role: .destructive) {
                        HistoryStore.standard.clear()
                        entries = []
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .onAppear { entries = HistoryStore.standard.entries() }
    }
}
