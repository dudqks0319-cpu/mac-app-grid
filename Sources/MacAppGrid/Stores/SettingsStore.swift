import Foundation
import SwiftUI
import Carbon

enum AppIconSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "작게"
        case .medium: return "보통"
        case .large: return "크게"
        }
    }

    var iconDimension: CGFloat {
        switch self {
        case .small: return 46
        case .medium: return 56
        case .large: return 68
        }
    }

    var cellWidth: CGFloat {
        switch self {
        case .small: return 68
        case .medium: return 76
        case .large: return 92
        }
    }

    var cellHeight: CGFloat {
        switch self {
        case .small: return 78
        case .medium: return 88
        case .large: return 104
        }
    }
}

struct SettingsConfig: Codable, Equatable {
    var closeAfterLaunchingApp: Bool = true
    var launchAtLogin: Bool = false
    var showMenuBarIcon: Bool = true
    var iconSize: AppIconSize = .medium
    var showRecentApps: Bool = true
    var showFrequentApps: Bool = true
    var hideFolderAppsInGrid: Bool = true
    var dragAppOntoAppCreatesFolder: Bool = true
    var hotKey: HotKeyConfig = .default
    var hiddenAppIDs: [String] = []
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
        config.hotKey = hotKey
    }

    func restoreDefaultHotKey() {
        config.hotKey = .default
    }

    private func save() {
        JSONFileStore.save(config, to: fileURL)
    }
}
