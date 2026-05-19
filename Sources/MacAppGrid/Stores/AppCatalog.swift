import SwiftUI
import AppKit
import Foundation

@MainActor
final class AppCatalog: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var query: String = ""
    @Published private(set) var isScanning = false

    init() {
        apps = AppCatalog.loadCachedApplications()
    }

    func reloadApps() {
        isScanning = true
        Task.detached(priority: .userInitiated) {
            let records = AppCatalog.scanApplicationRecords()
            await MainActor.run {
                let scannedApps = records.map { AppCatalog.appItem(from: $0) }
                self.apps = scannedApps
                self.isScanning = false
                AppCatalog.saveCachedApplications(records)
            }
        }
    }

    private static func loadCachedApplications() -> [AppItem] {
        guard let records = JSONFileStore.load([CachedAppRecord].self, from: cacheURL) else { return [] }
        return records
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { appItem(from: $0) }
    }

    private static func saveCachedApplications(_ records: [CachedAppRecord]) {
        JSONFileStore.save(records, to: cacheURL)
    }

    static func clearCache() {
        try? FileManager.default.removeItem(at: cacheURL)
    }

    private static var cacheURL: URL {
        AppPaths.jsonFile(named: "apps-cache.json")
    }

    nonisolated private static func scanApplicationRecords() -> [CachedAppRecord] {
        let searchPaths = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "\(NSHomeDirectory())/Applications"
        ]

        var found: [String: CachedAppRecord] = [:]
        let fileManager = FileManager.default

        for path in searchPaths {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
            let url = URL(fileURLWithPath: path)
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.localizedNameKey], options: [.skipsHiddenFiles]) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    enumerator.skipDescendants()
                    if let item = appRecord(from: fileURL) {
                        found[item.bundleID] = item
                    }
                }
            }
        }

        return found.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func appRecord(from url: URL) -> CachedAppRecord? {
        guard let bundle = Bundle(url: url) else { return nil }
        let bundleID = bundle.bundleIdentifier ?? url.path
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        return CachedAppRecord(id: bundleID, name: name, path: url.path, bundleID: bundleID)
    }

    private static func appItem(from record: CachedAppRecord) -> AppItem {
        AppItem(
            id: record.id,
            name: record.name,
            path: record.path,
            bundleID: record.bundleID,
            icon: IconCache.shared.icon(forPath: record.path)
        )
    }
}

private struct CachedAppRecord: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let bundleID: String
}
