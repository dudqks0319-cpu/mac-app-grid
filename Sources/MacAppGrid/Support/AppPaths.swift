import Foundation

enum AppPaths {
    static let appSupportDirectoryName = "MacAppGrid"

    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let directory = base.appendingPathComponent(appSupportDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static var backupsDirectory: URL {
        let directory = applicationSupportDirectory.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func jsonFile(named name: String) -> URL {
        applicationSupportDirectory.appendingPathComponent(name)
    }
}
