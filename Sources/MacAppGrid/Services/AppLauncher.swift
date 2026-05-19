import AppKit
import Foundation


@MainActor
func launch(app: AppItem) {
    let url = URL(fileURLWithPath: app.path)
    guard FileManager.default.fileExists(atPath: app.path) else {
        NotificationCenter.default.post(
            name: .appLaunchFailed,
            object: "\(app.name)을 찾을 수 없습니다. 앱 목록을 새로고침해 주세요."
        )
        return
    }

    let config = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
        Task { @MainActor in
            if let error {
                NotificationCenter.default.post(
                    name: .appLaunchFailed,
                    object: "\(app.name)을 실행하지 못했습니다. \(error.localizedDescription)"
                )
                return
            }

            UsageStore.shared.recordLaunch(bundleID: app.bundleID)
            if SettingsStore.shared.config.closeAfterLaunchingApp {
                NotificationCenter.default.post(name: .overlayHide, object: nil)
            }
        }
    }
}
