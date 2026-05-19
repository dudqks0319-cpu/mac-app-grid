import SwiftUI
import AppKit
import Foundation

@MainActor
final class AppCatalog: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var query: String = ""

    func reloadApps() {
        apps = AppCatalog.scanApplications()
    }

    private static func scanApplications() -> [AppItem] {
        let searchPaths = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "\(NSHomeDirectory())/Applications"
        ]

        var found: [String: AppItem] = [:]
        let fileManager = FileManager.default

        for path in searchPaths {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
            let url = URL(fileURLWithPath: path)
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.localizedNameKey], options: [.skipsHiddenFiles]) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    enumerator.skipDescendants()
                    if let item = appItem(from: fileURL) {
                        found[item.bundleID] = item
                    }
                }
            }
        }

        return found.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func appItem(from url: URL) -> AppItem? {
        guard let bundle = Bundle(url: url) else { return nil }
        let bundleID = bundle.bundleIdentifier ?? url.path
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return AppItem(id: bundleID, name: name, path: url.path, bundleID: bundleID, icon: icon)
    }
}
