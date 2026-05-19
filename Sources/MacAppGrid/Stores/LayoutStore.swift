import SwiftUI
import Foundation

@MainActor
final class LayoutStore: ObservableObject {
    @Published private(set) var orderedIDs: [String] = []

    private let orderKey = "MacAppGrid.layoutOrder"
    private let fileURL = AppPaths.jsonFile(named: "layout.json")

    init() {
        load()
    }

    func sync(with apps: [AppItem]) {
        let appIDs = Set(apps.map { $0.bundleID })
        var updated = orderedIDs.filter { appIDs.contains($0) }

        let existing = Set(updated)
        let newIDs = apps.map { $0.bundleID }.filter { !existing.contains($0) }
        updated.append(contentsOf: newIDs)

        if updated != orderedIDs {
            orderedIDs = updated
            save()
        }
    }

    func orderedApps(from apps: [AppItem]) -> [AppItem] {
        let lookup = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0) })
        return orderedIDs.compactMap { lookup[$0] }
    }

    func move(appID: String, to targetID: String?) {
        guard let fromIndex = orderedIDs.firstIndex(of: appID) else { return }
        var updated = orderedIDs
        updated.remove(at: fromIndex)

        if let targetID, let targetIndex = updated.firstIndex(of: targetID) {
            updated.insert(appID, at: targetIndex)
        } else {
            updated.append(appID)
        }

        orderedIDs = updated
        save()
    }

    func reset(with apps: [AppItem]) {
        orderedIDs = apps.map { $0.bundleID }
        save()
    }

    private func load() {
        if let payload = JSONFileStore.load(LayoutPayload.self, from: fileURL) {
            orderedIDs = payload.orderedIDs
            return
        }
        if let array = UserDefaults.standard.array(forKey: orderKey) as? [String] {
            orderedIDs = array
        }
    }

    private func save() {
        JSONFileStore.save(LayoutPayload(version: 1, orderedIDs: orderedIDs), to: fileURL)
    }
}

private struct LayoutPayload: Codable {
    var version: Int
    var orderedIDs: [String]
}
