import Foundation
import SwiftUI

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
    var hiddenAppIDs: [String] = []
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

    private let fileURL = AppPaths.jsonFile(named: "settings.json")

    private init() {
        config = JSONFileStore.load(SettingsConfig.self, from: fileURL) ?? SettingsConfig()
        config.launchAtLogin = LoginItemService.isEnabled
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
        do {
            try LoginItemService.setEnabled(enabled)
            loginItemError = nil
            config.launchAtLogin = LoginItemService.isEnabled
        } catch {
            loginItemError = error.localizedDescription
            config.launchAtLogin = LoginItemService.isEnabled
        }
    }

    private func save() {
        JSONFileStore.save(config, to: fileURL)
    }
}
