import SwiftUI
import Foundation

@MainActor
final class FolderStore: ObservableObject {
    @Published private(set) var folders: [Folder] = []

    private let foldersKey = "MacAppGrid.folders"

    init() {
        load()
    }

    func createFolder(name: String, initialAppID: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var folder = Folder(id: UUID().uuidString, name: trimmed, appIDs: [])
        if let appID = initialAppID {
            folder.appIDs = [appID]
        }
        folders.append(folder)
        save()
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

    func deleteFolder(folderID: String) {
        folders.removeAll { $0.id == folderID }
        save()
    }

    func renameFolder(folderID: String, newName: String) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folders[index].name = trimmed
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: foldersKey) else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([Folder].self, from: data) {
            folders = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(folders) else { return }
        UserDefaults.standard.set(data, forKey: foldersKey)
    }
}
