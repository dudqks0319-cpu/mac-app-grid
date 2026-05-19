import Foundation

enum AppVisibilityPolicy {
    static func appsForDisplay(
        visibleApps: [AppItem],
        folderAppIDs: Set<String>,
        searchText: String,
        hidesFolderAppsInGrid: Bool
    ) -> [AppItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty, hidesFolderAppsInGrid else {
            return visibleApps
        }
        return visibleApps.filter { !folderAppIDs.contains($0.bundleID) }
    }

    static func matchesSearch(_ app: AppItem, searchText: String) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return app.name.localizedCaseInsensitiveContains(trimmed)
            || app.bundleID.localizedCaseInsensitiveContains(trimmed)
    }
}
