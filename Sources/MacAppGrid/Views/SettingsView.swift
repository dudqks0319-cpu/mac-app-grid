import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore

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
            Toggle("메뉴바 아이콘 표시", isOn: binding(\.showMenuBarIcon))
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
                Text("현재 기본 단축키: Option + Space")
                    .foregroundColor(.secondary)
            }
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
}
