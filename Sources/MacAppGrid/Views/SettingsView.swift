import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var isRecordingHotKey = false
    @State private var hotKeyInputMessage: String?
    @State private var showMenuBarHideAlert = false

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("일반", systemImage: "gearshape")
                }

            viewSettings
                .tabItem {
                    Label("보기", systemImage: "square.grid.3x3")
                }

            hiddenAppsSettings
                .tabItem {
                    Label("숨긴 앱", systemImage: "eye.slash")
                }

            advancedSettings
                .tabItem {
                    Label("고급", systemImage: "wrench.and.screwdriver")
                }
        }
        .padding(24)
        .frame(width: 520, height: 420)
    }

    private var generalSettings: some View {
        Form {
            Toggle("앱 실행 후 런처 닫기", isOn: binding(\.closeAfterLaunchingApp))
            Toggle(
                "메뉴바 아이콘 표시",
                isOn: Binding(
                    get: { settings.config.showMenuBarIcon },
                    set: { value in
                        if value {
                            settings.config.showMenuBarIcon = true
                        } else if settings.isHotKeyRegistered {
                            showMenuBarHideAlert = true
                        } else {
                            settings.reportHotKeyInputMessage("단축키가 등록되지 않은 상태에서는 메뉴바 아이콘을 숨길 수 없습니다.")
                        }
                    }
                )
            )
            Toggle(
                "로그인 시 자동 실행",
                isOn: Binding(
                    get: { settings.config.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                )
            )
            if let error = settings.loginItemError {
                Text("로그인 항목 설정 실패: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("단축키")
                    .font(.headline)
                Text("현재 단축키: \(settings.config.hotKey.displayName)")
                    .foregroundColor(.secondary)
                HStack {
                    Button(isRecordingHotKey ? "입력 대기 중…" : "단축키 변경") {
                        hotKeyInputMessage = nil
                        isRecordingHotKey = true
                    }
                    if isRecordingHotKey {
                        Button("취소") {
                            isRecordingHotKey = false
                            hotKeyInputMessage = nil
                        }
                    }
                    Button("기본값 복원") {
                        hotKeyInputMessage = nil
                        settings.restoreDefaultHotKey()
                    }
                }
                if isRecordingHotKey {
                    Text("새 단축키를 누르세요. Command+Space, Control+Space, Fn+Shift+A는 충돌 가능성이 큽니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let hotKeyInputMessage {
                    Text(hotKeyInputMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                if let error = settings.hotKeyRegistrationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .background(
                HotKeyRecorderView(
                    isRecording: $isRecordingHotKey,
                    onRecord: { hotKey in
                        hotKeyInputMessage = nil
                        settings.setHotKey(hotKey)
                    },
                    onCancel: {
                        hotKeyInputMessage = nil
                    },
                    onMessage: { message in
                        hotKeyInputMessage = message
                    }
                )
                .frame(width: 1, height: 1)
                .opacity(0.01)
            )
        }
        .alert("메뉴바 아이콘을 숨길까요?", isPresented: $showMenuBarHideAlert) {
            Button("숨기기", role: .destructive) {
                settings.config.showMenuBarIcon = false
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("메뉴바 아이콘을 숨기면 단축키로만 MacAppGrid를 열 수 있습니다. 단축키가 동작하지 않으면 앱을 다시 실행해 복구해야 할 수 있습니다.")
        }
    }

    private var viewSettings: some View {
        Form {
            Picker("아이콘 크기", selection: binding(\.iconSize)) {
                ForEach(AppIconSize.allCases) { size in
                    Text(size.title).tag(size)
                }
            }
            .pickerStyle(.segmented)

            Toggle("최근 앱 표시", isOn: binding(\.showRecentApps))
            Toggle("자주 쓰는 앱 표시", isOn: binding(\.showFrequentApps))
            Toggle("폴더에 포함된 앱을 전체 앱에서 숨기기", isOn: binding(\.hideFolderAppsInGrid))
            Toggle("앱을 앱 위로 드롭하면 폴더 생성", isOn: binding(\.dragAppOntoAppCreatesFolder))
        }
    }

    private var hiddenAppsSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            if settings.config.hiddenAppIDs.isEmpty {
                Text("숨긴 앱이 없습니다.")
                    .foregroundColor(.secondary)
            } else {
                List(settings.config.hiddenAppIDs.sorted(), id: \.self) { appID in
                    HStack {
                        Text(appID)
                            .lineLimit(1)
                        Spacer()
                        Button("복원") {
                            settings.unhideApp(appID)
                        }
                    }
                }
                Button("전체 복원") {
                    settings.unhideAllApps()
                }
            }
        }
    }

    private var advancedSettings: some View {
        Form {
            Button("앱 목록 새로고침") {
                NotificationCenter.default.post(name: .appRefreshRequested, object: nil)
            }
            Button("레이아웃 초기화") {
                NotificationCenter.default.post(name: .layoutResetRequested, object: nil)
            }
            Button("앱 캐시 삭제") {
                AppCatalog.clearCache()
                NotificationCenter.default.post(name: .appRefreshRequested, object: nil)
            }
            Button("아이콘 캐시 삭제") {
                IconCache.shared.clear()
                NotificationCenter.default.post(name: .appRefreshRequested, object: nil)
            }
            Button("Application Support 폴더 열기") {
                NSWorkspace.shared.open(AppPaths.applicationSupportDirectory)
            }
            Button("백업 폴더 열기") {
                NSWorkspace.shared.open(AppPaths.backupsDirectory)
            }
            Button("진단 정보 복사") {
                copyDiagnostics()
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("저장 위치")
                    .font(.headline)
                Text(AppPaths.applicationSupportDirectory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<SettingsConfig, Value>) -> Binding<Value> {
        Binding(
            get: { settings.config[keyPath: keyPath] },
            set: { settings.config[keyPath: keyPath] = $0 }
        )
    }

    private func copyDiagnostics() {
        let diagnostics = """
        MacAppGrid Diagnostics
        Version: 0.1.0
        Support: \(AppPaths.applicationSupportDirectory.path)
        HotKey: \(settings.config.hotKey.displayName)
        HiddenApps: \(settings.config.hiddenAppIDs.count)
        LaunchAtLogin: \(settings.config.launchAtLogin)
        HideFolderAppsInGrid: \(settings.config.hideFolderAppsInGrid)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
    }
}

private struct HotKeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (HotKeyConfig) -> Void
    let onCancel: () -> Void
    let onMessage: (String) -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.onRecord = { hotKey in
            onRecord(hotKey)
            isRecording = false
        }
        nsView.onCancel = {
            onCancel()
            isRecording = false
        }
        nsView.onMessage = onMessage
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class RecorderNSView: NSView {
        var isRecording = false
        var onRecord: ((HotKeyConfig) -> Void)?
        var onCancel: (() -> Void)?
        var onMessage: ((String) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard isRecording else {
                super.keyDown(with: event)
                return
            }
            if event.keyCode == UInt16(kVK_Escape) {
                onCancel?()
                isRecording = false
                return
            }
            let modifierFlags = carbonModifierFlags(from: event.modifierFlags)
            guard modifierFlags != 0 else {
                onMessage?("Command, Option, Control, Shift 중 하나 이상을 함께 눌러야 합니다.")
                return
            }
            onRecord?(
                HotKeyConfig(
                    modifierFlags: modifierFlags,
                    keyCode: UInt32(event.keyCode),
                    displayName: displayName(for: event, modifierFlags: event.modifierFlags)
                )
            )
            isRecording = false
        }

        private func carbonModifierFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var result: UInt32 = 0
            if flags.contains(.command) { result |= UInt32(cmdKey) }
            if flags.contains(.option) { result |= UInt32(optionKey) }
            if flags.contains(.control) { result |= UInt32(controlKey) }
            if flags.contains(.shift) { result |= UInt32(shiftKey) }
            return result
        }

        private func displayName(for event: NSEvent, modifierFlags: NSEvent.ModifierFlags) -> String {
            var parts: [String] = []
            if modifierFlags.contains(.command) { parts.append("Command") }
            if modifierFlags.contains(.option) { parts.append("Option") }
            if modifierFlags.contains(.control) { parts.append("Control") }
            if modifierFlags.contains(.shift) { parts.append("Shift") }
            parts.append(keyName(for: event))
            return parts.joined(separator: " + ")
        }

        private func keyName(for event: NSEvent) -> String {
            if event.keyCode == UInt16(kVK_Space) {
                return "Space"
            }
            return event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        }
    }
}
