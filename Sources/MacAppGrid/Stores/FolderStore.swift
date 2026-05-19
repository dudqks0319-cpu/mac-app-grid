import SwiftUI
import Foundation

@MainActor
final class FolderStore: ObservableObject {
    @Published private(set) var folders: [Folder] = []

    private let foldersKey = "MacAppGrid.folders"
    private let fileURL: URL

    init(fileURL: URL = AppPaths.jsonFile(named: "folders.json")) {
        self.fileURL = fileURL
        load()
    }

    @discardableResult
    func createFolder(name: String, initialAppID: String? = nil) -> String? {
        createFolder(name: name, initialAppIDs: initialAppID.map { [$0] } ?? [])
    }

    @discardableResult
    func createFolder(name: String, initialAppIDs: [String]) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var folder = Folder(id: UUID().uuidString, name: trimmed, appIDs: [])
        for appID in initialAppIDs where !folder.appIDs.contains(appID) {
            folder.appIDs.append(appID)
        }
        folders.append(folder)
        save()
        return folder.id
    }

    func addApp(appID: String, to folderID: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        if !folders[index].appIDs.contains(appID) {
            folders[index].appIDs.append(appID)
            save()
        }
    }

    func removeApp(appID: String, from folderID: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[index].appIDs.removeAll { $0 == appID }
        save()
    }

    func moveApp(appID: String, to targetAppID: String?, in folderID: String) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }),
              let fromIndex = folders[folderIndex].appIDs.firstIndex(of: appID) else { return }
        var appIDs = folders[folderIndex].appIDs
        appIDs.remove(at: fromIndex)
        if let targetAppID, let targetIndex = appIDs.firstIndex(of: targetAppID) {
            appIDs.insert(appID, at: targetIndex)
        } else {
            appIDs.append(appID)
        }
        folders[folderIndex].appIDs = appIDs
        save()
    }

    func deleteFolder(folderID: String) {
        folders.removeAll { $0.id == folderID }
        save()
    }

    func appIDsInFolders() -> Set<String> {
        Set(folders.flatMap(\.appIDs))
    }

    func renameFolder(folderID: String, newName: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folders[index].name = trimmed
        save()
    }

    private func load() {
        if let decoded = JSONFileStore.load([Folder].self, from: fileURL) {
            folders = decoded
            return
        }
        guard let data = UserDefaults.standard.data(forKey: foldersKey),
              let decoded = try? JSONDecoder().decode([Folder].self, from: data) else {
            return
        }
        folders = decoded
    }

    private func save() {
        JSONFileStore.save(folders, to: fileURL)
    }
}
