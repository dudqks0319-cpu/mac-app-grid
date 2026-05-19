import Foundation
import SwiftUI
import Carbon

enum AppIconSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "작게"
        case .medium: return "보통"
        case .large: return "크게"
        case .extraLarge: return "아주 크게"
        }
    }

    var iconDimension: CGFloat {
        switch self {
        case .small: return 58
        case .medium: return 72
        case .large: return 90
        case .extraLarge: return 106
        }
    }

    var cellWidth: CGFloat {
        switch self {
        case .small: return 88
        case .medium: return 108
        case .large: return 128
        case .extraLarge: return 150
        }
    }

    var cellHeight: CGFloat {
        switch self {
        case .small: return 106
        case .medium: return 126
        case .large: return 150
        case .extraLarge: return 172
        }
    }
}

enum AppSortMode: String, Codable, CaseIterable, Identifiable {
    case customLayout
    case original
    case nameAscending
    case recentlyOpened

    var id: String { rawValue }

    var title: String {
        switch self {
        case .customLayout: return "사용자 배치"
        case .original: return "기존 앱 순서"
        case .nameAscending: return "이름순"
        case .recentlyOpened: return "최근 실행순"
        }
    }
}

struct SettingsConfig: Codable, Equatable {
    var closeAfterLaunchingApp: Bool = true
    var launchAtLogin: Bool = false
    var showMenuBarIcon: Bool = true
    var iconSize: AppIconSize = .large
    var showRecentApps: Bool = true
    var showFrequentApps: Bool = true
    var appSortMode: AppSortMode = .customLayout
    var hideFolderAppsInGrid: Bool = true
    var dragAppOntoAppCreatesFolder: Bool = true
    var hotKey: HotKeyConfig = .default
    var hiddenAppIDs: [String] = []

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        closeAfterLaunchingApp = try container.decodeIfPresent(Bool.self, forKey: .closeAfterLaunchingApp) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        iconSize = try container.decodeIfPresent(AppIconSize.self, forKey: .iconSize) ?? .large
        showRecentApps = try container.decodeIfPresent(Bool.self, forKey: .showRecentApps) ?? true
        showFrequentApps = try container.decodeIfPresent(Bool.self, forKey: .showFrequentApps) ?? true
        appSortMode = try container.decodeIfPresent(AppSortMode.self, forKey: .appSortMode) ?? .customLayout
        hideFolderAppsInGrid = try container.decodeIfPresent(Bool.self, forKey: .hideFolderAppsInGrid) ?? true
        dragAppOntoAppCreatesFolder = try container.decodeIfPresent(Bool.self, forKey: .dragAppOntoAppCreatesFolder) ?? true
        hotKey = try container.decodeIfPresent(HotKeyConfig.self, forKey: .hotKey) ?? .default
        hiddenAppIDs = try container.decodeIfPresent([String].self, forKey: .hiddenAppIDs) ?? []
    }
}

struct HotKeyConfig: Codable, Equatable {
    var modifierFlags: UInt32
    var keyCode: UInt32
    var displayName: String

    static let `default` = HotKeyConfig(
        modifierFlags: UInt32(optionKey),
        keyCode: UInt32(kVK_Space),
        displayName: "Option + Space"
    )

    static let launchpadStyle = HotKeyConfig(
        modifierFlags: UInt32(cmdKey),
        keyCode: UInt32(kVK_ANSI_L),
        displayName: "Command + L"
    )
}

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var config: SettingsConfig {
        didSet {
            save()
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    @Published private(set) var loginItemError: String?
    @Published private(set) var hotKeyRegistrationError: String?
    @Published private(set) var isHotKeyRegistered = true

    private let fileURL: URL
    private let syncsLoginItemState: Bool

    init(fileURL: URL = AppPaths.jsonFile(named: "settings.json"), syncLoginItemState: Bool = true) {
        self.fileURL = fileURL
        self.syncsLoginItemState = syncLoginItemState
        config = JSONFileStore.load(SettingsConfig.self, from: fileURL) ?? SettingsConfig()
        if syncLoginItemState {
            config.launchAtLogin = LoginItemService.isEnabled
        }
    }

    func isHidden(_ appID: String) -> Bool {
        config.hiddenAppIDs.contains(appID)
    }

    func hideApp(_ appID: String) {
        guard !config.hiddenAppIDs.contains(appID) else { return }
        config.hiddenAppIDs.append(appID)
        config.hiddenAppIDs.sort()
    }

    func unhideApp(_ appID: String) {
        config.hiddenAppIDs.removeAll { $0 == appID }
    }

    func unhideAllApps() {
        config.hiddenAppIDs = []
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard syncsLoginItemState else {
            config.launchAtLogin = enabled
            return
        }
        do {
            try LoginItemService.setEnabled(enabled)
            loginItemError = nil
            config.launchAtLogin = LoginItemService.isEnabled
        } catch {
            loginItemError = error.localizedDescription
            config.launchAtLogin = LoginItemService.isEnabled
        }
    }

    func setHotKey(_ hotKey: HotKeyConfig) {
        hotKeyRegistrationError = knownConflictMessage(for: hotKey)
        config.hotKey = hotKey
    }

    func restoreDefaultHotKey() {
        hotKeyRegistrationError = nil
        config.hotKey = .default
    }

    func reportHotKeyRegistrationSuccess() {
        isHotKeyRegistered = true
    }

    func rejectHotKey(_ rejectedHotKey: HotKeyConfig, fallback: HotKeyConfig, status: OSStatus) {
        isHotKeyRegistered = false
        hotKeyRegistrationError = """
        \(rejectedHotKey.displayName)은 등록되지 않았습니다. 다른 앱 또는 macOS 시스템 단축키와 충돌할 수 있습니다. 기존 단축키 \(fallback.displayName)로 되돌렸습니다. 오류 코드: \(status)
        """
        if config.hotKey != fallback {
            config.hotKey = fallback
        }
    }

    func reportHotKeyInputMessage(_ message: String?) {
        hotKeyRegistrationError = message
    }

    private func save() {
        JSONFileStore.save(config, to: fileURL)
    }

    private func knownConflictMessage(for hotKey: HotKeyConfig) -> String? {
        if hotKey.modifierFlags == UInt32(cmdKey), hotKey.keyCode == UInt32(kVK_Space) {
            return "Command + Space는 Spotlight와 충돌할 수 있습니다."
        }
        if hotKey.modifierFlags == UInt32(controlKey), hotKey.keyCode == UInt32(kVK_Space) {
            return "Control + Space는 입력 소스 전환과 충돌할 수 있습니다."
        }
        return nil
    }
}
