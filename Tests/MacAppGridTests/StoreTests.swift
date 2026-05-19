import AppKit
import XCTest
@testable import MacAppGrid

final class StoreTests: XCTestCase {
    func testJSONFileStoreBacksUpCorruptFile() throws {
        let root = try makeTemporaryDirectory()
        setenv("MAC_APP_GRID_SUPPORT_DIR", root.path, 1)
        defer { unsetenv("MAC_APP_GRID_SUPPORT_DIR") }

        let url = root.appendingPathComponent("settings.json")
        try "{broken json".data(using: .utf8)?.write(to: url)

        let loaded = JSONFileStore.load(SettingsConfig.self, from: url)

        XCTAssertNil(loaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let backups = try FileManager.default.contentsOfDirectory(at: AppPaths.backupsDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(backups.count, 1)
    }

    @MainActor
    func testLayoutStorePersistsOrder() throws {
        let root = try makeTemporaryDirectory()
        let url = root.appendingPathComponent("layout.json")
        let apps = [
            makeApp(id: "com.example.a", name: "A"),
            makeApp(id: "com.example.b", name: "B"),
            makeApp(id: "com.example.c", name: "C")
        ]

        let store = LayoutStore(fileURL: url, migratesUserDefaults: false)
        store.sync(with: apps)
        store.move(appID: "com.example.c", to: "com.example.a")

        let restored = LayoutStore(fileURL: url, migratesUserDefaults: false)
        XCTAssertEqual(restored.orderedIDs, ["com.example.c", "com.example.a", "com.example.b"])
    }

    @MainActor
    func testFolderStoreCRUDAndOrdering() throws {
        let root = try makeTemporaryDirectory()
        let url = root.appendingPathComponent("folders.json")

        let store = FolderStore(fileURL: url)
        let folderID = try XCTUnwrap(store.createFolder(name: "Dev", initialAppIDs: ["a", "b"]))
        store.renameFolder(folderID: folderID, newName: "Tools")
        store.addApp(appID: "c", to: folderID)
        store.moveApp(appID: "c", to: "a", in: folderID)
        store.removeApp(appID: "b", from: folderID)

        let restored = FolderStore(fileURL: url)
        XCTAssertEqual(restored.folders.first?.name, "Tools")
        XCTAssertEqual(restored.folders.first?.appIDs, ["c", "a"])
        XCTAssertEqual(restored.appIDsInFolders(), Set(["a", "c"]))
    }

    @MainActor
    func testSettingsStorePersistsHiddenAppsAndHotKey() throws {
        let root = try makeTemporaryDirectory()
        let url = root.appendingPathComponent("settings.json")

        let store = SettingsStore(fileURL: url, syncLoginItemState: false)
        store.hideApp("com.example.hidden")
        store.setHotKey(HotKeyConfig(modifierFlags: 1, keyCode: 49, displayName: "Test + Space"))

        let restored = SettingsStore(fileURL: url, syncLoginItemState: false)
        XCTAssertTrue(restored.isHidden("com.example.hidden"))
        XCTAssertEqual(restored.config.hotKey.displayName, "Test + Space")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacAppGridTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeApp(id: String, name: String) -> AppItem {
        AppItem(id: id, name: name, path: "/Applications/\(name).app", bundleID: id, icon: NSImage())
    }
}
